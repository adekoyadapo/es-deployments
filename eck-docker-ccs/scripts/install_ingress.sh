#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
ensure_env_file

if kubectl -n ingress-nginx get deployment ingress-nginx-controller >/dev/null 2>&1; then
  echo "nginx ingress controller already installed"
else
  kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v${INGRESS_NGINX_VERSION}/deploy/static/provider/cloud/deploy.yaml"
fi

kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout="${K8S_INGRESS_ROLLOUT_TIMEOUT}"
