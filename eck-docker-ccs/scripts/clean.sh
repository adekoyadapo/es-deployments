#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

rm -rf "${CERT_DIR}" "${RUNTIME_DIR}"
echo "Removed generated certs and runtime files"
