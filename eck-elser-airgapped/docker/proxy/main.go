package main

import (
	"bytes"
	"crypto/tls"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

var hopHeaders = map[string]struct{}{
	"Connection":          {},
	"Proxy-Connection":    {},
	"Keep-Alive":          {},
	"Proxy-Authenticate":  {},
	"Proxy-Authorization": {},
	"Te":                  {},
	"Trailer":             {},
	"Transfer-Encoding":   {},
	"Upgrade":             {},
}

func main() {
	port := os.Getenv("PROXY_PORT")
	if port == "" {
		port = "3128"
	}

	handler := http.HandlerFunc(proxyHandler)

	server := &http.Server{
		Addr:              "0.0.0.0:" + port,
		Handler:           handler,
		ReadHeaderTimeout: 10 * time.Second,
	}

	log.Printf("proxy listening on %s", server.Addr)
	log.Fatal(server.ListenAndServe())
}

func proxyHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet && r.URL.Path == "/health" {
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok\n"))
		return
	}
	if r.Method == http.MethodConnect {
		handleConnect(w, r)
		return
	}
	handleForward(w, r)
}

func handleConnect(w http.ResponseWriter, r *http.Request) {
	target := r.Host
	if target == "" {
		target = r.URL.Host
	}
	if !strings.Contains(target, ":") {
		target += ":443"
	}
	log.Printf("CONNECT %s", target)

	upstream, err := net.DialTimeout("tcp", target, 10*time.Second)
	if err != nil {
		http.Error(w, "connect failed: "+err.Error(), http.StatusBadGateway)
		return
	}
	defer upstream.Close()

	hijacker, ok := w.(http.Hijacker)
	if !ok {
		http.Error(w, "hijacking not supported", http.StatusInternalServerError)
		return
	}

	clientConn, buf, err := hijacker.Hijack()
	if err != nil {
		http.Error(w, "hijack failed: "+err.Error(), http.StatusInternalServerError)
		return
	}
	defer clientConn.Close()

	_, _ = clientConn.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))
	if buf.Reader.Buffered() > 0 {
		_, _ = io.Copy(upstream, buf)
	}

	errc := make(chan error, 2)
	go func() {
		_, err := io.Copy(upstream, clientConn)
		errc <- err
	}()
	go func() {
		_, err := io.Copy(clientConn, upstream)
		errc <- err
	}()
	<-errc
}

func handleForward(w http.ResponseWriter, r *http.Request) {
	targetURL, err := targetURL(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "read body failed: "+err.Error(), http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	req, err := http.NewRequestWithContext(r.Context(), r.Method, targetURL.String(), bytes.NewReader(body))
	if err != nil {
		http.Error(w, "request build failed: "+err.Error(), http.StatusBadGateway)
		return
	}
	req.Header = cloneHeaders(r.Header)
	req.Host = targetURL.Host
	removeHopHeaders(req.Header)

	transport := &http.Transport{
		Proxy:                 nil,
		TLSClientConfig:       &tls.Config{},
		DisableCompression:    false,
		MaxIdleConns:          100,
		IdleConnTimeout:       30 * time.Second,
		ResponseHeaderTimeout: 30 * time.Second,
	}

	log.Printf("%s %s", r.Method, targetURL.String())
	resp, err := transport.RoundTrip(req)
	if err != nil {
		http.Error(w, "upstream request failed: "+err.Error(), http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	removeHopHeaders(resp.Header)
	copyHeaders(w.Header(), resp.Header)
	w.WriteHeader(resp.StatusCode)
	_, _ = io.Copy(w, resp.Body)
}

func targetURL(r *http.Request) (*url.URL, error) {
	if r.URL != nil && r.URL.Scheme != "" && r.URL.Host != "" {
		return r.URL, nil
	}
	host := r.Host
	if host == "" {
		return nil, http.ErrNoLocation
	}
	return url.Parse("http://" + host + r.RequestURI)
}

func cloneHeaders(src http.Header) http.Header {
	dst := make(http.Header, len(src))
	for key, values := range src {
		copied := append([]string(nil), values...)
		dst[key] = copied
	}
	return dst
}

func removeHopHeaders(headers http.Header) {
	for key := range hopHeaders {
		headers.Del(key)
	}
}

func copyHeaders(dst, src http.Header) {
	for key, values := range src {
		for _, value := range values {
			dst.Add(key, value)
		}
	}
}
