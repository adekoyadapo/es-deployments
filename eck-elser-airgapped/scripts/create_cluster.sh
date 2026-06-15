#!/usr/bin/env bash
set -euo pipefail

source ./scripts/common.sh

if ! command -v k3d >/dev/null 2>&1; then
  echo "k3d is required" >&2
  exit 1
fi

mkdir -p "${MODEL_ARTIFACTS_DIR}"

if k3d cluster list | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
  echo "k3d cluster ${CLUSTER_NAME} already exists"
else
  k3d cluster create "${CLUSTER_NAME}" \
    --servers 1 \
    --agents 2 \
    --wait \
    --volume "${MODEL_ARTIFACTS_DIR}:${MODEL_ARTIFACTS_NODE_PATH}@all" \
    -p "5601:5601@loadbalancer" \
    -p "9200:9200@loadbalancer"
fi

kubectl config use-context "k3d-${CLUSTER_NAME}" >/dev/null
kubectl get nodes >/dev/null
