#!/usr/bin/env bash
set -euo pipefail

source ./scripts/common.sh
validate_mode_value

render_manifest manifests/namespaces.yaml | kubectl apply -f -

case "${MODE}" in
  file)
    render_manifest manifests/elastic/elasticsearch-file.yaml | kubectl apply -f -
    ;;
  http)
    render_manifest manifests/elastic/http-model-repository.yaml | kubectl apply -f -
    kubectl -n "${NAMESPACE}" rollout status deploy/elser-model-repository --timeout=180s
    render_manifest manifests/elastic/elasticsearch-http.yaml | kubectl apply -f -
    ;;
  jina)
    ./scripts/start_jina_docker.sh
    render_manifest manifests/elastic/elasticsearch-jina.yaml | kubectl apply -f -
    ;;
  proxy)
    bash ./scripts/build_proxy_image.sh
    render_manifest manifests/elastic/proxy.yaml | kubectl apply -f -
    kubectl -n "${NAMESPACE}" rollout status deploy/proxy --timeout=180s
    render_manifest manifests/elastic/elasticsearch-proxy.yaml | kubectl apply -f -
    ;;
esac

if [[ "${MODE}" == "proxy" ]]; then
  render_manifest manifests/elastic/kibana-proxy.yaml | kubectl apply -f -
else
  render_manifest manifests/elastic/kibana.yaml | kubectl apply -f -
fi
