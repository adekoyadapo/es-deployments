#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
ensure_env_file
write_runtime_env
load_runtime_env

mkdir -p "${CERT_DIR}/ca" "${CERT_DIR}/remote-http" "${CERT_DIR}/remote-transport" "${CERT_DIR}/remote-rcs" "${RUNTIME_DIR}"

make_ca() {
  local name="$1"
  local crt="${CERT_DIR}/ca/${name}.crt"
  local key="${CERT_DIR}/ca/${name}.key"
  if [[ ! -f "${crt}" || ! -f "${key}" ]]; then
    openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
      -subj "/CN=${name}" -keyout "${key}" -out "${crt}" >/dev/null 2>&1
  fi
}

make_cert() {
  local name="$1"
  local ca="$2"
  local dir="${CERT_DIR}/${name}"
  local key="${dir}/${name}.key"
  local csr="${dir}/${name}.csr"
  local crt="${dir}/${name}.crt"
  local ext="${dir}/${name}.ext"

  cat >"${ext}" <<EOF
subjectAltName = DNS:${name},DNS:localhost,DNS:${REMOTE_HOST_IN_K3D},DNS:remote-es,DNS:remote-http,DNS:${DOCKER_ES_HOST},DNS:${REMOTE_RCS_HOST},DNS:${REMOTE_TRANSPORT_HOST},IP:127.0.0.1,IP:${HOST_IP}
extendedKeyUsage = serverAuth, clientAuth
EOF
  openssl req -new -newkey rsa:4096 -nodes -subj "/CN=${name}" \
    -keyout "${key}" -out "${csr}" >/dev/null 2>&1
  openssl x509 -req -sha256 -days 3650 -in "${csr}" \
    -CA "${CERT_DIR}/ca/${ca}.crt" -CAkey "${CERT_DIR}/ca/${ca}.key" -CAcreateserial \
    -out "${crt}" -extfile "${ext}" >/dev/null 2>&1
  rm -f "${csr}"
}

make_ca remote-http-ca
make_ca remote-transport-ca
make_ca remote-rcs-ca

make_cert remote-http remote-http-ca
make_cert remote-transport remote-transport-ca
make_cert remote-rcs remote-rcs-ca

cp "${CERT_DIR}/ca/remote-transport-ca.crt" "${CERT_DIR}/trusted-transport-ca.crt"

echo "Certificates ready in ${CERT_DIR}"
