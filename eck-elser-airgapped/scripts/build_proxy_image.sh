#!/usr/bin/env bash
set -euo pipefail

source ./scripts/common.sh

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

mkdir -p "${tmp_dir}/gocache"
GO111MODULE=off GOCACHE="${tmp_dir}/gocache" GOOS=linux GOARCH="$(go env GOARCH)" CGO_ENABLED=0 go build -o "${tmp_dir}/proxy" ./docker/proxy/main.go
cp docker/proxy/Dockerfile "${tmp_dir}/Dockerfile"

docker build -t "${PROXY_IMAGE}" "${tmp_dir}"
k3d image import -c "${CLUSTER_NAME}" "${PROXY_IMAGE}"

echo "Built and imported ${PROXY_IMAGE}"
