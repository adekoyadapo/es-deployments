#!/usr/bin/env bash
set -euo pipefail

source ./scripts/common.sh

check_image() {
  local image="$1"
  if ! docker manifest inspect "${image}:${ES_VERSION}" >/dev/null 2>&1; then
    echo "Image tag not found: ${image}:${ES_VERSION}" >&2
    return 1
  fi
}

check_image "docker.elastic.co/elasticsearch/elasticsearch"
check_image "docker.elastic.co/kibana/kibana"

echo "ES_VERSION ${ES_VERSION} is available for Elasticsearch and Kibana images"
