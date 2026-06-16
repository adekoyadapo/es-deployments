#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
validate_mode

for cmd in docker k3d kubectl curl jq openssl nc; do
  command -v "${cmd}" >/dev/null 2>&1 || die "${cmd} is required"
done

docker compose version >/dev/null 2>&1 || die "docker compose is required"
docker info >/dev/null 2>&1 || die "Docker is not running"

echo "Dependencies OK"
