#!/usr/bin/env bash
set -euo pipefail

source ./scripts/common.sh
validate_mode_value

for _ in $(seq 1 90); do
  if kubectl -n "${NAMESPACE}" get pods -l elasticsearch.k8s.elastic.co/cluster-name=elasticsearch -o name | grep -q .; then
    break
  fi
  sleep 2
done

kubectl -n "${NAMESPACE}" wait --for=condition=Ready pod -l elasticsearch.k8s.elastic.co/cluster-name=elasticsearch --timeout=900s
kubectl -n "${NAMESPACE}" wait --for=condition=Ready pod -l kibana.k8s.elastic.co/name=kibana --timeout=600s

if [[ "${MODE}" == "http" ]]; then
  kubectl -n "${NAMESPACE}" rollout status deploy/elser-model-repository --timeout=180s
fi

if [[ "${MODE}" == "jina" ]]; then
  ./scripts/start_jina_docker.sh
fi

if [[ "${MODE}" == "proxy" ]]; then
  kubectl -n "${NAMESPACE}" rollout status deploy/proxy --timeout=180s
fi

echo "ECK ${MODE} environment is ready"
