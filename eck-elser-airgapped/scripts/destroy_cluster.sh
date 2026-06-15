#!/usr/bin/env bash
set -euo pipefail

source ./scripts/common.sh

docker rm -f "${JINA_CONTAINER_NAME}" >/dev/null 2>&1 || true

if command -v k3d >/dev/null 2>&1; then
  if k3d cluster list | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
    k3d cluster delete "${CLUSTER_NAME}"
  fi
fi
