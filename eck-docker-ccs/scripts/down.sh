#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
ensure_env_file

cd "${ROOT_DIR}"
compose down -v --remove-orphans || true
if k3d cluster list | awk 'NR > 1 {print $1}' | grep -qx "${K3D_CLUSTER}"; then
  k3d cluster delete "${K3D_CLUSTER}"
fi
