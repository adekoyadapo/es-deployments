#!/usr/bin/env bash
set -euo pipefail

source ./scripts/common.sh

OPERATOR_MANIFEST="manifests/elastic/eck-operator.yaml"
CRDS_MANIFEST="manifests/elastic/eck-crds.yaml"
VERSION_MARKER="manifests/elastic/.eck-version"

if [[ ! -s "${OPERATOR_MANIFEST}" ]] || [[ ! -s "${CRDS_MANIFEST}" ]] || [[ ! -s "${VERSION_MARKER}" ]] || [[ "$(cat "${VERSION_MARKER}" 2>/dev/null || true)" != "${ECK_VERSION}" ]]; then
  curl -fsSL "https://download.elastic.co/downloads/eck/${ECK_VERSION}/operator.yaml" -o "${OPERATOR_MANIFEST}"
  curl -fsSL "https://download.elastic.co/downloads/eck/${ECK_VERSION}/crds.yaml" -o "${CRDS_MANIFEST}"
  printf '%s\n' "${ECK_VERSION}" > "${VERSION_MARKER}"
fi

render_manifest manifests/namespaces.yaml | kubectl apply -f -
kubectl apply -f "${CRDS_MANIFEST}"
kubectl apply -f "${OPERATOR_MANIFEST}"

kubectl wait --for=condition=Established --timeout=240s crd/elasticsearches.elasticsearch.k8s.elastic.co
kubectl wait --for=condition=Established --timeout=240s crd/kibanas.kibana.k8s.elastic.co
kubectl -n elastic-system rollout status statefulset/elastic-operator --timeout=300s
