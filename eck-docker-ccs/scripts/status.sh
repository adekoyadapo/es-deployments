#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
ensure_env_file

kubectl config use-context "k3d-${K3D_CLUSTER}" >/dev/null 2>&1 || true
kubectl get nodes || true
kubectl -n elastic-system get pods || true
kubectl -n ingress-nginx get pods,svc || true
kubectl -n "${NAMESPACE}" get elasticsearch,kibana,ingress,pods,svc,configmap,secret || true
compose ps || true
./scripts/ingress_hosts.sh || true
