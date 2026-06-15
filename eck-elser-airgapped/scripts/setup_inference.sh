#!/usr/bin/env bash
set -euo pipefail

source ./scripts/common.sh
validate_mode_value

trap stop_es_port_forward EXIT
start_es_port_forward
ELASTIC_PASSWORD="$(elastic_password)"
export ELASTIC_PASSWORD

wait_for_elastic_endpoint() {
  for _ in $(seq 1 120); do
    stats="$(es_api GET "/_ml/trained_models/${ELSER_MODEL_ID}/_stats" || true)"
    if [[ "${stats}" == *'"state":"fully_allocated"'* ]] || [[ "${stats}" == *'"state":"started"'* ]]; then
      echo "ELSER model deployment is allocated"
      return 0
    fi
    sleep 5
  done
  echo "Timed out waiting for ELSER model allocation" >&2
  es_api GET "/_ml/trained_models/${ELSER_MODEL_ID}/_stats" || true
  exit 1
}

case "${MODE}" in
  file|http)
    body="$(cat <<JSON
{
  "service": "elasticsearch",
  "service_settings": {
    "model_id": "${ELSER_MODEL_ID}",
    "num_threads": 1,
    "adaptive_allocations": {
      "enabled": true,
      "min_number_of_allocations": 1,
      "max_number_of_allocations": 1
    }
  }
}
JSON
)"
    es_api PUT "/_inference/sparse_embedding/${ELSER_ENDPOINT_ID}?timeout=10m" "${body}"
    wait_for_elastic_endpoint
    ;;
  jina)
    ./scripts/start_jina_docker.sh
    JINA_BASE_URL="$(jina_base_url)"
    body="$(cat <<JSON
{
  "service": "custom",
  "service_settings": {
    "url": "${JINA_BASE_URL}/v1/embeddings",
    "headers": {
      "Content-Type": "application/json"
    },
    "request": "{\\"input\\": \${input}, \\"model\\": \\"${JINA_MODEL}\\"}",
    "response": {
      "json_parser": {
        "text_embeddings": "$.data[*].embedding[*]"
      }
    }
  }
}
JSON
)"
    es_api PUT "/_inference/text_embedding/${JINA_ENDPOINT_ID}" "${body}"
    ;;
esac

echo "Inference endpoint configured for MODE=${MODE}"
