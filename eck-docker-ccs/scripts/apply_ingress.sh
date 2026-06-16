#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
ensure_env_file
load_runtime_env

render_ingress() {
  local file="$1"
  sed \
    -e "s|__NAMESPACE__|${NAMESPACE}|g" \
    -e "s|__ECK_CLUSTER__|${ECK_CLUSTER}|g" \
    -e "s|__ES_INGRESS_HOST__|${ES_INGRESS_HOST}|g" \
    -e "s|__KB_INGRESS_HOST__|${KB_INGRESS_HOST}|g" \
    "${file}"
}

render_ingress manifests/elasticsearch-ingress.yaml | kubectl apply -f -
render_ingress manifests/kibana-ingress.yaml | kubectl apply -f -
