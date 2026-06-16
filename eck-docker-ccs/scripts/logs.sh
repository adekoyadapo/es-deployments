#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
ensure_env_file

kubectl -n elastic-system logs statefulset/elastic-operator --tail=120 || true
kubectl -n "${NAMESPACE}" logs "statefulset/${ECK_CLUSTER}-es-default" --tail=120 || true
kubectl -n "${NAMESPACE}" logs "deployment/kibana-kb" --tail=80 || true
compose logs --tail=120 remote-es || true
compose logs --tail=120 remote-kibana || true
