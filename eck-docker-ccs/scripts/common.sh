#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${MODE:-api-key}"
ES_VERSION="${ES_VERSION:-9.4.2}"
ECK_VERSION="${ECK_VERSION:-3.4.0}"
K3D_CLUSTER="${K3D_CLUSTER:-eck-docker-ccs}"
NAMESPACE="${NAMESPACE:-ccs-lab}"
ECK_CLUSTER="${ECK_CLUSTER:-main}"
REMOTE_ALIAS="${REMOTE_ALIAS:-remote-docker}"

REMOTE_CLUSTER_NAME="${REMOTE_CLUSTER_NAME:-remote-docker}"
REMOTE_HTTP_PORT="${REMOTE_HTTP_PORT:-9201}"
REMOTE_TRANSPORT_PORT="${REMOTE_TRANSPORT_PORT:-9300}"
REMOTE_CLUSTER_SERVER_PORT="${REMOTE_CLUSTER_SERVER_PORT:-9443}"
REMOTE_KIBANA_PORT="${REMOTE_KIBANA_PORT:-5602}"
ELASTIC_PASSWORD="${ELASTIC_PASSWORD:-changeme}"
KIBANA_PASSWORD="${KIBANA_PASSWORD:-changeme}"
INGRESS_HOST_STYLE="${INGRESS_HOST_STYLE:-short}"
INGRESS_NGINX_VERSION="${INGRESS_NGINX_VERSION:-1.15.1}"
K8S_INGRESS_ROLLOUT_TIMEOUT="${K8S_INGRESS_ROLLOUT_TIMEOUT:-900s}"

LOCAL_ES_PORT="${LOCAL_ES_PORT:-19200}"
LOCAL_KIBANA_PORT="${LOCAL_KIBANA_PORT:-15601}"
REMOTE_HOST_IN_K3D="${REMOTE_HOST_IN_K3D:-host.k3d.internal}"
REMOTE_RCS_SERVER_NAME="${REMOTE_RCS_SERVER_NAME:-remote-rcs}"
REMOTE_TRANSPORT_SERVER_NAME="${REMOTE_TRANSPORT_SERVER_NAME:-remote-transport}"

CERT_DIR="${ROOT_DIR}/certs"
RUNTIME_DIR="${ROOT_DIR}/runtime"
GENERATED_DIR="${ROOT_DIR}/generated"
RUNTIME_ENV="${RUNTIME_DIR}/runtime.env"

export ROOT_DIR MODE ES_VERSION ECK_VERSION K3D_CLUSTER NAMESPACE ECK_CLUSTER REMOTE_ALIAS
export REMOTE_CLUSTER_NAME REMOTE_HTTP_PORT REMOTE_TRANSPORT_PORT REMOTE_CLUSTER_SERVER_PORT REMOTE_KIBANA_PORT
export ELASTIC_PASSWORD KIBANA_PASSWORD LOCAL_ES_PORT LOCAL_KIBANA_PORT REMOTE_HOST_IN_K3D
export REMOTE_RCS_SERVER_NAME REMOTE_TRANSPORT_SERVER_NAME CERT_DIR RUNTIME_DIR GENERATED_DIR RUNTIME_ENV
export INGRESS_HOST_STYLE INGRESS_NGINX_VERSION K8S_INGRESS_ROLLOUT_TIMEOUT

die() {
  echo "ERROR: $*" >&2
  exit 1
}

validate_mode() {
  case "${MODE}" in
    api-key|cert) ;;
    *) die "Unsupported MODE=${MODE}. Use MODE=api-key or MODE=cert." ;;
  esac
}

render_manifest() {
  local file="$1"
  load_runtime_env
  sed \
    -e "s|__NAMESPACE__|${NAMESPACE}|g" \
    -e "s|__ES_VERSION__|${ES_VERSION}|g" \
    -e "s|__ECK_CLUSTER__|${ECK_CLUSTER}|g" \
    -e "s|__KB_INGRESS_HOST__|${KB_INGRESS_HOST}|g" \
    "${file}"
}

compose() {
  load_runtime_env
  docker compose --env-file "${ROOT_DIR}/.env" -f "${ROOT_DIR}/docker-compose.yml" "$@"
}

ensure_env_file() {
  if [[ ! -f "${ROOT_DIR}/.env" ]]; then
    cp "${ROOT_DIR}/.env.example" "${ROOT_DIR}/.env"
  fi
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
}

detect_host_ip() {
  local ip=""

  if command -v ipconfig >/dev/null 2>&1; then
    ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
    if [[ -z "${ip}" ]]; then
      ip="$(ipconfig getifaddr en1 2>/dev/null || true)"
    fi
  fi

  if [[ -z "${ip}" ]] && command -v ip >/dev/null 2>&1; then
    ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')"
  fi

  if [[ -z "${ip}" ]] && command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi

  [[ -n "${ip}" ]] || die "Unable to detect a host IP address automatically"
  printf '%s' "${ip}"
}

sslip_host_from_ip() {
  local ip="$1"
  printf '%s.sslip.io' "${ip//./-}"
}

write_runtime_env_from_ip() {
  local host_ip="$1"
  local sslip_host es_prefix kb_prefix
  mkdir -p "${RUNTIME_DIR}"
  sslip_host="$(sslip_host_from_ip "${host_ip}")"

  case "${INGRESS_HOST_STYLE}" in
    short|stack) ;;
    *) die "Invalid INGRESS_HOST_STYLE=${INGRESS_HOST_STYLE}. Use short or stack." ;;
  esac

  if [[ "${INGRESS_HOST_STYLE}" == "stack" ]]; then
    es_prefix="${ECK_CLUSTER}"
    kb_prefix="kibana"
  else
    es_prefix="es"
    kb_prefix="kb"
  fi

  cat >"${RUNTIME_ENV}" <<EOF
HOST_IP=${host_ip}
INGRESS_BASE_HOST=${sslip_host}
ES_INGRESS_HOST=${es_prefix}.${sslip_host}
KB_INGRESS_HOST=${kb_prefix}.${sslip_host}
DOCKER_ES_HOST=remote-es.${sslip_host}
DOCKER_KB_HOST=remote-kb.${sslip_host}
REMOTE_RCS_HOST=remote-rcs.${sslip_host}
REMOTE_TRANSPORT_HOST=remote-transport.${sslip_host}
EOF
}

write_runtime_env() {
  local host_ip="${INGRESS_IP:-}"
  if [[ -z "${host_ip}" ]]; then
    host_ip="$(detect_host_ip)"
  fi
  write_runtime_env_from_ip "${host_ip}"
}

load_runtime_env() {
  if [[ ! -f "${RUNTIME_ENV}" ]]; then
    write_runtime_env
  fi
  set -a
  # shellcheck disable=SC1090
  source "${RUNTIME_ENV}"
  set +a
}

eck_password() {
  kubectl -n "${NAMESPACE}" get secret "${ECK_CLUSTER}-es-elastic-user" -o jsonpath='{.data.elastic}' | base64 -d
}

start_port_forward() {
  mkdir -p "${RUNTIME_DIR}"
  local service="$1"
  local local_port="$2"
  local remote_port="$3"
  local log_file="${RUNTIME_DIR}/${service}-${local_port}.log"
  kubectl -n "${NAMESPACE}" port-forward "svc/${service}" "${local_port}:${remote_port}" >"${log_file}" 2>&1 &
  local pid="$!"

  for _ in $(seq 1 60); do
    if nc -z 127.0.0.1 "${local_port}" >/dev/null 2>&1; then
      printf '%s\n' "${pid}"
      return 0
    fi
    if ! kill -0 "${pid}" >/dev/null 2>&1; then
      cat "${log_file}" >&2 || true
      die "Port-forward for ${service} exited early."
    fi
    sleep 1
  done

  cat "${log_file}" >&2 || true
  die "Timed out waiting for ${service} port-forward on ${local_port}."
}

stop_pid() {
  local pid="${1:-}"
  if [[ -n "${pid}" ]] && kill -0 "${pid}" >/dev/null 2>&1; then
    kill "${pid}" >/dev/null 2>&1 || true
  fi
}

main_es_api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local password="${MAIN_ELASTIC_PASSWORD:-$(eck_password)}"
  local base_url="${MAIN_ES_URL:-}"

  if [[ -z "${base_url}" ]]; then
    load_runtime_env
    base_url="https://${ES_INGRESS_HOST}"
  fi

  if [[ -n "${body}" ]]; then
    curl -sk --fail-with-body --noproxy "*" --resolve "${ES_INGRESS_HOST}:443:${HOST_IP}" \
      -u "elastic:${password}" -H "Content-Type: application/json" \
      -X "${method}" "${base_url}${path}" --data-binary "${body}"
  else
    curl -sk --fail-with-body --noproxy "*" --resolve "${ES_INGRESS_HOST}:443:${HOST_IP}" \
      -u "elastic:${password}" -X "${method}" "${base_url}${path}"
  fi
}

kibana_api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local password="${MAIN_ELASTIC_PASSWORD:-$(eck_password)}"
  local base_url="${MAIN_KIBANA_URL:-}"

  if [[ -z "${base_url}" ]]; then
    load_runtime_env
    base_url="https://${KB_INGRESS_HOST}"
  fi

  if [[ -n "${body}" ]]; then
    curl -sk --fail-with-body --noproxy "*" --resolve "${KB_INGRESS_HOST}:443:${HOST_IP}" \
      -u "elastic:${password}" -H "kbn-xsrf: true" -H "Content-Type: application/json" \
      -X "${method}" "${base_url}${path}" --data-binary "${body}"
  else
    curl -sk --fail-with-body --noproxy "*" --resolve "${KB_INGRESS_HOST}:443:${HOST_IP}" \
      -u "elastic:${password}" -H "kbn-xsrf: true" -X "${method}" "${base_url}${path}"
  fi
}

remote_es_api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local url="https://127.0.0.1:${REMOTE_HTTP_PORT}${path}"

  if [[ -n "${body}" ]]; then
    curl -s --fail-with-body --cacert "${CERT_DIR}/ca/remote-http-ca.crt" \
      -u "elastic:${ELASTIC_PASSWORD}" -H "Content-Type: application/json" \
      -X "${method}" "${url}" --data-binary "${body}"
  else
    curl -s --fail-with-body --cacert "${CERT_DIR}/ca/remote-http-ca.crt" \
      -u "elastic:${ELASTIC_PASSWORD}" -X "${method}" "${url}"
  fi
}

remote_es_ingress_api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  load_runtime_env
  local url="https://${DOCKER_ES_HOST}:${REMOTE_HTTP_PORT}${path}"

  if [[ -n "${body}" ]]; then
    curl -s --fail-with-body --noproxy "*" --cacert "${CERT_DIR}/ca/remote-http-ca.crt" \
      --resolve "${DOCKER_ES_HOST}:${REMOTE_HTTP_PORT}:${HOST_IP}" \
      -u "elastic:${ELASTIC_PASSWORD}" -H "Content-Type: application/json" \
      -X "${method}" "${url}" --data-binary "${body}"
  else
    curl -s --fail-with-body --noproxy "*" --cacert "${CERT_DIR}/ca/remote-http-ca.crt" \
      --resolve "${DOCKER_ES_HOST}:${REMOTE_HTTP_PORT}:${HOST_IP}" \
      -u "elastic:${ELASTIC_PASSWORD}" -X "${method}" "${url}"
  fi
}

wait_for_remote() {
  for _ in $(seq 1 90); do
    if remote_es_api GET "/_cluster/health?wait_for_status=yellow&timeout=1s" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  compose logs remote-es >&2 || true
  die "Remote Docker Elasticsearch did not become ready."
}

configure_remote_kibana_system_user() {
  remote_es_api POST "/_security/user/kibana_system/_password" \
    "{\"password\":\"${KIBANA_PASSWORD}\"}" >/dev/null
}

wait_for_remote_kibana() {
  load_runtime_env
  for _ in $(seq 1 90); do
    if curl -s --max-time 2 --noproxy "*" --resolve "${DOCKER_KB_HOST}:${REMOTE_KIBANA_PORT}:${HOST_IP}" \
      "http://${DOCKER_KB_HOST}:${REMOTE_KIBANA_PORT}/api/status" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  compose logs remote-kibana >&2 || true
  die "Remote Docker Kibana did not become reachable."
}

wait_for_eck() {
  for _ in $(seq 1 300); do
    if [[ "$(kubectl -n "${NAMESPACE}" get elasticsearch "${ECK_CLUSTER}" -o jsonpath='{.status.phase}' 2>/dev/null || true)" == "Ready" ]]; then
      break
    fi
    sleep 2
  done
  [[ "$(kubectl -n "${NAMESPACE}" get elasticsearch "${ECK_CLUSTER}" -o jsonpath='{.status.phase}' 2>/dev/null || true)" == "Ready" ]] \
    || die "ECK Elasticsearch ${ECK_CLUSTER} did not become Ready."

  for _ in $(seq 1 300); do
    if [[ "$(kubectl -n "${NAMESPACE}" get kibana kibana -o jsonpath='{.status.health}' 2>/dev/null || true)" == "green" ]]; then
      break
    fi
    sleep 2
  done
  [[ "$(kubectl -n "${NAMESPACE}" get kibana kibana -o jsonpath='{.status.health}' 2>/dev/null || true)" == "green" ]] \
    || die "ECK Kibana did not become green."
}

wait_for_main_api() {
  MAIN_ELASTIC_PASSWORD="${MAIN_ELASTIC_PASSWORD:-$(eck_password)}"
  export MAIN_ELASTIC_PASSWORD

  for _ in $(seq 1 90); do
    if main_es_api GET "/_cluster/health?wait_for_status=yellow&timeout=2s" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  die "ECK Elasticsearch API did not become reachable through ingress."
}

wait_for_main_kibana_api() {
  MAIN_ELASTIC_PASSWORD="${MAIN_ELASTIC_PASSWORD:-$(eck_password)}"
  export MAIN_ELASTIC_PASSWORD

  for _ in $(seq 1 90); do
    if kibana_api GET "/api/status" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  die "ECK Kibana API did not become reachable through ingress."
}

copy_file_to_configmap() {
  local name="$1"
  local key="$2"
  local file="$3"
  kubectl -n "${NAMESPACE}" create configmap "${name}" \
    "--from-file=${key}=${file}" \
    --dry-run=client -o yaml | kubectl apply -f -
}

wait_for_remote_connection() {
  for _ in $(seq 1 60); do
    main_es_api GET "/${REMOTE_ALIAS}:connection-probe/_search?ignore_unavailable=true&allow_no_indices=true" '{"size":0}' >/dev/null 2>&1 || true
    if main_es_api GET "/_remote/info" | jq -e --arg alias "${REMOTE_ALIAS}" '.[$alias].connected == true' >/dev/null; then
      return 0
    fi
    sleep 2
  done
  main_es_api GET "/_remote/info" | jq . >&2 || true
  die "Remote cluster ${REMOTE_ALIAS} did not report connected."
}

put_remote_cluster_settings() {
  local remote_address="$1"
  local server_name="$2"
  local body

  body="{
  \"persistent\": {
    \"cluster\": {
      \"remote\": {
        \"${REMOTE_ALIAS}\": {
          \"mode\": \"proxy\",
          \"proxy_address\": \"${remote_address}\",
          \"server_name\": \"${server_name}\",
          \"skip_unavailable\": false
        }
      }
    }
  }
}"

  for _ in $(seq 1 30); do
    if main_es_api PUT "/_cluster/settings" "${body}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  main_es_api PUT "/_cluster/settings" "${body}" >/dev/null
}
