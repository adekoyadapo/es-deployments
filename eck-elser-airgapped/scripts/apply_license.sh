#!/usr/bin/env bash
set -euo pipefail

source ./scripts/common.sh

license_type() {
  es_api GET "/_license" | ruby -rjson -e 'puts JSON.parse(STDIN.read).dig("license", "type").to_s'
}

ml_available() {
  es_api GET "/_xpack/usage" | ruby -rjson -e 'j=JSON.parse(STDIN.read); exit(j.dig("ml", "available") == true ? 0 : 1)'
}

if [[ -n "${LICENSE_FILE:-}" ]]; then
  if [[ ! -s "${LICENSE_FILE}" ]]; then
    echo "LICENSE_FILE does not exist or is empty: ${LICENSE_FILE}" >&2
    exit 1
  fi

  kubectl -n elastic-system delete secret eck-license --ignore-not-found >/dev/null 2>&1 || true
  kubectl -n elastic-system create secret generic eck-license --from-file=license="${LICENSE_FILE}"
  kubectl -n elastic-system label secret eck-license "license.k8s.elastic.co/scope=operator" --overwrite
else
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: eck-trial-license
  namespace: elastic-system
  labels:
    license.k8s.elastic.co/type: enterprise_trial
  annotations:
    elastic.co/eula: accepted
EOF
fi

trap stop_es_port_forward EXIT
start_es_port_forward
ELASTIC_PASSWORD="$(elastic_password)"
export ELASTIC_PASSWORD

for _ in $(seq 1 90); do
  current_type="$(license_type || true)"
  if ml_available >/dev/null 2>&1; then
    echo "ECK license applied. Elasticsearch license type: ${current_type}"
    exit 0
  fi
  sleep 2
done

echo "Timed out waiting for an ML-capable ECK license." >&2
echo "Current Elasticsearch license:" >&2
es_api GET "/_license" >&2 || true
cat >&2 <<EOF

For ECK, use an Enterprise trial secret or an orchestration license secret in the elastic-system namespace.
See: https://www.elastic.co/docs/deploy-manage/license/manage-your-license-in-eck
EOF
exit 1
