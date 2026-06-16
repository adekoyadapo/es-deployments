#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
ensure_env_file
load_runtime_env

eck_value() {
  kubectl -n "${NAMESPACE}" get secret "${ECK_CLUSTER}-es-elastic-user" -o jsonpath='{.data.elastic}' 2>/dev/null | base64 -d 2>/dev/null || true
}

cat <<EOF
ECK main cluster
  Elasticsearch: https://${ES_INGRESS_HOST}
  Kibana:        https://${KB_INGRESS_HOST}
  Username:      elastic
  Password:      $(eck_value)

Docker remote cluster
  Elasticsearch: https://${DOCKER_ES_HOST}:${REMOTE_HTTP_PORT}
  Kibana:        http://${DOCKER_KB_HOST}:${REMOTE_KIBANA_PORT}
  Username:      elastic
  Password:      ${ELASTIC_PASSWORD}

Docker Kibana backend user
  Username:      kibana_system
  Password:      ${KIBANA_PASSWORD}

Detected ingress host IP
  HOST_IP:       ${HOST_IP}
  Base domain:   ${INGRESS_BASE_HOST}
EOF
