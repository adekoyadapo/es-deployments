#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
ensure_env_file
load_runtime_env

mkdir -p "${CERT_DIR}/ingress"

create_tls_secret() {
  local name="$1"
  local host="$2"
  local crt="${CERT_DIR}/ingress/${name}.crt"
  local key="${CERT_DIR}/ingress/${name}.key"

  openssl req -x509 -nodes -newkey rsa:2048 \
    -days 365 \
    -keyout "${key}" \
    -out "${crt}" \
    -subj "/CN=${host}" \
    -addext "subjectAltName=DNS:${host}" >/dev/null 2>&1

  kubectl -n "${NAMESPACE}" create secret tls "${name}" \
    --cert="${crt}" \
    --key="${key}" \
    --dry-run=client -o yaml | kubectl apply -f -
}

create_tls_secret "${ECK_CLUSTER}-ingress-tls" "${ES_INGRESS_HOST}"
create_tls_secret "kibana-ingress-tls" "${KB_INGRESS_HOST}"
