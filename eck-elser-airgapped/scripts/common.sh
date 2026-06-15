#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

MODE="${MODE:-file}"
ES_VERSION="${ES_VERSION:-9.4.2}"
ECK_VERSION="${ECK_VERSION:-3.4.0}"
NAMESPACE="${NAMESPACE:-elser-lab}"
CLUSTER_NAME="${CLUSTER_NAME:-eck-elser-airgap}"
MODEL_ARTIFACTS_DIR="${MODEL_ARTIFACTS_DIR:-$(pwd)/artifacts/elser}"
MODEL_ARTIFACTS_NODE_PATH="${MODEL_ARTIFACTS_NODE_PATH:-/mnt/elser-models}"
ELSER_MODEL_ID="${ELSER_MODEL_ID:-.elser_model_2}"
ELSER_ENDPOINT_ID="${ELSER_ENDPOINT_ID:-elser-airgap}"
JINA_MODEL="${JINA_MODEL:-jina-embeddings-v5-text-small}"
JINA_IMAGE="${JINA_IMAGE:-ghcr.io/jina-ai/jina-airgap/jina-embeddings-v5-text-small:cpu}"
JINA_ENDPOINT_ID="${JINA_ENDPOINT_ID:-jina-airgap}"
JINA_PORT="${JINA_PORT:-18080}"
JINA_CONTAINER_NAME="${JINA_CONTAINER_NAME:-eck-elser-jina}"
LOCAL_ES_PORT="${LOCAL_ES_PORT:-19200}"

validate_mode_value() {
  case "${MODE}" in
    file|http|jina) ;;
    *)
      echo "Unsupported MODE=${MODE}. Use MODE=file, MODE=http, or MODE=jina." >&2
      exit 1
      ;;
  esac
}

render_manifest() {
  local file="$1"
  sed \
    -e "s|__NAMESPACE__|${NAMESPACE}|g" \
    -e "s|__ES_VERSION__|${ES_VERSION}|g" \
    -e "s|__MODEL_ARTIFACTS_NODE_PATH__|${MODEL_ARTIFACTS_NODE_PATH}|g" \
    -e "s|__JINA_IMAGE__|${JINA_IMAGE}|g" \
    "${file}"
}

detect_host_ip() {
  if [[ -n "${HOST_IP:-}" ]]; then
    printf '%s\n' "${HOST_IP}"
    return 0
  fi

  if command -v ipconfig >/dev/null 2>&1; then
    for iface in en0 en1; do
      ipconfig getifaddr "${iface}" 2>/dev/null && return 0
    done
  fi

  if command -v route >/dev/null 2>&1; then
    local route_ip
    route_ip="$(route -n get 1.1.1.1 2>/dev/null | awk '/interface:/{iface=$2} END{if (iface) system("ipconfig getifaddr " iface)}' || true)"
    if [[ -n "${route_ip}" ]]; then
      printf '%s\n' "${route_ip}"
      return 0
    fi
  fi

  if command -v ifconfig >/dev/null 2>&1; then
    local ifconfig_ip
    ifconfig_ip="$(ifconfig 2>/dev/null | awk '
      /^[a-zA-Z0-9]+:/ { iface=$1; sub(":", "", iface); active=0 }
      /status: active/ { active=1 }
      active && iface !~ /^(lo|awdl|llw|utun|bridge|vmenet)/ && $1 == "inet" && $2 !~ /^127\./ { print $2; exit }
    ' || true)"
    if [[ -z "${ifconfig_ip}" ]]; then
      ifconfig_ip="$(ifconfig 2>/dev/null | awk '$1 == "inet" && $2 !~ /^127\./ { print $2; exit }' || true)"
    fi
    if [[ -n "${ifconfig_ip}" ]]; then
      printf '%s\n' "${ifconfig_ip}"
      return 0
    fi
  fi

  hostname -I 2>/dev/null | awk '{print $1}'
}

sslip_host() {
  local ip="${1:-$(detect_host_ip)}"
  printf '%s.sslip.io\n' "${ip//./-}"
}

jina_base_url() {
  local host="${JINA_HOST:-$(sslip_host)}"
  printf 'http://%s:%s\n' "${host}" "${JINA_PORT}"
}

elastic_password() {
  kubectl -n "${NAMESPACE}" get secret elasticsearch-es-elastic-user -o jsonpath='{.data.elastic}' | base64 -d
}

start_es_port_forward() {
  local log_file="/tmp/eck-elser-es-port-forward.log"
  kubectl -n "${NAMESPACE}" port-forward "svc/elasticsearch-es-http" "${LOCAL_ES_PORT}:9200" >"${log_file}" 2>&1 &
  ES_PORT_FORWARD_PID="$!"
  export ES_PORT_FORWARD_PID

  for _ in $(seq 1 60); do
    if curl -sk "https://127.0.0.1:${LOCAL_ES_PORT}" >/dev/null 2>&1; then
      return 0
    fi
    if ! kill -0 "${ES_PORT_FORWARD_PID}" >/dev/null 2>&1; then
      echo "Elasticsearch port-forward exited early. Log:" >&2
      cat "${log_file}" >&2 || true
      exit 1
    fi
    sleep 1
  done

  echo "Timed out waiting for Elasticsearch port-forward on ${LOCAL_ES_PORT}. Log:" >&2
  cat "${log_file}" >&2 || true
  exit 1
}

stop_es_port_forward() {
  if [[ -n "${ES_PORT_FORWARD_PID:-}" ]] && kill -0 "${ES_PORT_FORWARD_PID}" >/dev/null 2>&1; then
    kill "${ES_PORT_FORWARD_PID}" >/dev/null 2>&1 || true
  fi
}

es_api() {
  local method="$1"
  local request_path="$2"
  local body="${3:-}"
  local password="${ELASTIC_PASSWORD:-$(elastic_password)}"

  if [[ -n "${body}" ]]; then
    curl -sk -u "elastic:${password}" -H "Content-Type: application/json" -X "${method}" \
      "https://127.0.0.1:${LOCAL_ES_PORT}${request_path}" --data-binary "${body}"
  else
    curl -sk -u "elastic:${password}" -X "${method}" "https://127.0.0.1:${LOCAL_ES_PORT}${request_path}"
  fi
}
