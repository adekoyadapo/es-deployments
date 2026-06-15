#!/usr/bin/env bash
set -euo pipefail

source ./scripts/common.sh

JINA_BASE_URL="$(jina_base_url)"

if docker ps --format '{{.Names}}' | grep -qx "${JINA_CONTAINER_NAME}"; then
  echo "Jina Docker service already running at ${JINA_BASE_URL}"
else
  docker rm -f "${JINA_CONTAINER_NAME}" >/dev/null 2>&1 || true
  docker run -d \
    --platform linux/amd64 \
    --name "${JINA_CONTAINER_NAME}" \
    -p "${JINA_PORT}:8080" \
    -e HF_HUB_OFFLINE=1 \
    -e TRANSFORMERS_OFFLINE=1 \
    "${JINA_IMAGE}" >/dev/null
fi

for _ in $(seq 1 120); do
  if curl -fsS "${JINA_BASE_URL}/health" >/dev/null 2>&1; then
    echo "Jina Docker service is ready at ${JINA_BASE_URL}"
    exit 0
  fi
  sleep 2
done

echo "Timed out waiting for Jina Docker service at ${JINA_BASE_URL}" >&2
docker logs "${JINA_CONTAINER_NAME}" --tail=200 >&2 || true
exit 1
