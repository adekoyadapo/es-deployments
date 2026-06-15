#!/usr/bin/env bash
set -euo pipefail

source ./scripts/common.sh

kubectl -n elastic-system logs statefulset/elastic-operator --tail=200 || true
kubectl -n "${NAMESPACE}" logs -l elasticsearch.k8s.elastic.co/cluster-name=elasticsearch --tail=200 || true
kubectl -n "${NAMESPACE}" logs -l kibana.k8s.elastic.co/name=kibana --tail=200 || true
kubectl -n "${NAMESPACE}" logs deploy/proxy --tail=200 || true
kubectl -n "${NAMESPACE}" logs deploy/elser-model-repository --tail=200 || true
docker logs "${JINA_CONTAINER_NAME}" --tail=200 || true
