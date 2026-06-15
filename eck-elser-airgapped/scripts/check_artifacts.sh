#!/usr/bin/env bash
set -euo pipefail

source ./scripts/common.sh

required=(
  "elser_model_2.metadata.json"
  "elser_model_2.pt"
  "elser_model_2.vocab.json"
)

missing=0
for artifact in "${required[@]}"; do
  if [[ ! -s "${MODEL_ARTIFACTS_DIR}/${artifact}" ]]; then
    echo "Missing ${MODEL_ARTIFACTS_DIR}/${artifact}" >&2
    missing=1
  fi
done

if [[ "${missing}" -ne 0 ]]; then
  cat >&2 <<EOF

Download the cross-platform ELSER v2 artifacts into:
  ${MODEL_ARTIFACTS_DIR}

Required files:
  https://ml-models.elastic.co/elser_model_2.metadata.json
  https://ml-models.elastic.co/elser_model_2.pt
  https://ml-models.elastic.co/elser_model_2.vocab.json
EOF
  exit 1
fi

echo "Found cross-platform ELSER v2 artifacts in ${MODEL_ARTIFACTS_DIR}"
