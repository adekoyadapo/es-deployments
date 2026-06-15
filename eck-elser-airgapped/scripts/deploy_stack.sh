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
esac

render_manifest manifests/elastic/kibana.yaml | kubectl apply -f -
