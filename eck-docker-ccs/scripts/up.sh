#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
validate_mode
ensure_env_file
write_runtime_env
load_runtime_env

cd "${ROOT_DIR}"
mkdir -p "${RUNTIME_DIR}"

if ! k3d cluster list | awk 'NR > 1 {print $1}' | grep -qx "${K3D_CLUSTER}"; then
  k3d cluster create "${K3D_CLUSTER}" \
    --servers 1 \
    --agents 1 \
    --port "80:80@loadbalancer" \
    --port "443:443@loadbalancer" \
    --k3s-arg "--disable=traefik@server:0" \
    --wait
fi
kubectl config use-context "k3d-${K3D_CLUSTER}" >/dev/null

render_manifest manifests/namespaces.yaml | kubectl apply -f -
./scripts/install_ingress.sh
kubectl apply -f "https://download.elastic.co/downloads/eck/${ECK_VERSION}/crds.yaml"
kubectl apply -f "https://download.elastic.co/downloads/eck/${ECK_VERSION}/operator.yaml"
kubectl -n elastic-system rollout status statefulset/elastic-operator --timeout=180s
kubectl apply -f manifests/trial-license.yaml

copy_file_to_configmap remote-transport-ca ca.crt "${CERT_DIR}/ca/remote-transport-ca.crt"
copy_file_to_configmap remote-rcs-ca remote-rcs-ca.crt "${CERT_DIR}/ca/remote-rcs-ca.crt"

if [[ "${MODE}" == "api-key" ]]; then
  kubectl -n "${NAMESPACE}" create secret generic remote-api-keys \
    --from-literal="cluster.remote.${REMOTE_ALIAS}.credentials=placeholder" \
    --dry-run=client -o yaml | kubectl apply -f -
else
  kubectl -n "${NAMESPACE}" create secret generic remote-api-keys \
    --dry-run=client -o yaml | kubectl apply -f -
fi

render_manifest manifests/eck-stack.yaml | kubectl apply -f -
wait_for_eck
./scripts/create_ingress_tls.sh
./scripts/apply_ingress.sh

kubectl -n "${NAMESPACE}" get secret "${ECK_CLUSTER}-es-transport-certs-public" \
  -o go-template='{{index .data "ca.crt" | base64decode}}' >"${CERT_DIR}/ca/eck-transport-ca.crt"

if [[ "${MODE}" == "cert" ]]; then
  cat "${CERT_DIR}/ca/remote-transport-ca.crt" "${CERT_DIR}/ca/eck-transport-ca.crt" >"${CERT_DIR}/trusted-transport-ca.crt"
else
  cp "${CERT_DIR}/ca/remote-transport-ca.crt" "${CERT_DIR}/trusted-transport-ca.crt"
fi

compose up -d
wait_for_remote
configure_remote_kibana_system_user
compose restart remote-kibana >/dev/null
wait_for_remote_kibana
remote_es_api POST "/_license/start_trial?acknowledge=true" >/dev/null 2>&1 || true

if [[ "${MODE}" == "api-key" ]]; then
  encoded="$(remote_es_api POST "/_security/cross_cluster/api_key" '{
    "name": "eck-docker-ccs",
    "access": {
      "search": [
        { "names": [ "remote-products" ] }
      ],
      "replication": [
        { "names": [ "remote-leader" ] }
      ]
    }
  }' | jq -r '.encoded')"
  [[ -n "${encoded}" && "${encoded}" != "null" ]] || die "Failed to create cross-cluster API key"

  kubectl -n "${NAMESPACE}" create secret generic remote-api-keys \
    --from-literal="cluster.remote.${REMOTE_ALIAS}.credentials=${encoded}" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n "${NAMESPACE}" rollout restart statefulset "${ECK_CLUSTER}-es-default"
  kubectl -n "${NAMESPACE}" delete pod "${ECK_CLUSTER}-es-default-0" --wait=false >/dev/null 2>&1 || true
  wait_for_eck
elif [[ "${MODE}" == "cert" ]]; then
  compose restart remote-es
  wait_for_remote
fi

MAIN_ELASTIC_PASSWORD="$(eck_password)"
export MAIN_ELASTIC_PASSWORD
wait_for_main_api

if [[ "${MODE}" == "api-key" ]]; then
  remote_address="${REMOTE_RCS_HOST}:${REMOTE_CLUSTER_SERVER_PORT}"
  server_name="${REMOTE_RCS_SERVER_NAME}"
else
  remote_address="${REMOTE_TRANSPORT_HOST}:${REMOTE_TRANSPORT_PORT}"
  server_name="${REMOTE_TRANSPORT_SERVER_NAME}"
fi

put_remote_cluster_settings "${remote_address}" "${server_name}"
wait_for_remote_connection
main_es_api GET "/_remote/info" | jq .

cat <<EOF

Environment ready
Mode:              ${MODE}
Main Elasticsearch: https://${ES_INGRESS_HOST}
Main Kibana:        https://${KB_INGRESS_HOST}
Remote Elasticsearch: https://${DOCKER_ES_HOST}:${REMOTE_HTTP_PORT}
Remote Kibana:        http://${DOCKER_KB_HOST}:${REMOTE_KIBANA_PORT}
Remote alias:      ${REMOTE_ALIAS}
EOF
