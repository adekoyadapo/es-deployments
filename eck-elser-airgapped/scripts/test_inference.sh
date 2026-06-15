#!/usr/bin/env bash
set -euo pipefail

source ./scripts/common.sh
validate_mode_value

trap stop_es_port_forward EXIT
start_es_port_forward
ELASTIC_PASSWORD="$(elastic_password)"
export ELASTIC_PASSWORD

case "${MODE}" in
  file|http|proxy)
    response="$(es_api POST "/_inference/sparse_embedding/${ELSER_ENDPOINT_ID}" '{"input":["How do I deploy ELSER in an air gapped Kubernetes environment?"]}')"
    echo "${response}" | grep -q '"is_truncated"'

    es_api PUT "/elser-airgap-demo" '{
      "mappings": {
        "properties": {
          "title": { "type": "text" },
          "body": { "type": "text" },
          "ml.tokens": { "type": "sparse_vector" }
        }
      }
    }' >/dev/null

    es_api PUT "/_ingest/pipeline/elser-airgap-pipeline" "{
      \"processors\": [
        {
          \"inference\": {
            \"model_id\": \"${ELSER_MODEL_ID}\",
            \"input_output\": [
              {
                \"input_field\": \"body\",
                \"output_field\": \"ml.tokens\"
              }
            ]
          }
        }
      ]
    }" >/dev/null

    es_api POST "/elser-airgap-demo/_doc/1?pipeline=elser-airgap-pipeline&refresh=true" '{
      "title": "Air-gapped ELSER",
      "body": "Use local model artifacts with ECK to deploy ELSER without internet access."
    }' >/dev/null
    es_api POST "/elser-airgap-demo/_doc/2?pipeline=elser-airgap-pipeline&refresh=true" '{
      "title": "Unrelated",
      "body": "A vegetable garden needs water and sunlight during the summer."
    }' >/dev/null

    search_response="$(es_api GET "/elser-airgap-demo/_search" "{
      \"query\": {
        \"sparse_vector\": {
          \"field\": \"ml.tokens\",
          \"inference_id\": \"${ELSER_ENDPOINT_ID}\",
          \"query\": \"air gapped elasticsearch model deployment\"
        }
      },
      \"size\": 1
    }")"
    echo "${search_response}" | grep -q '"_id":"1"'
    if [[ "${MODE}" == "proxy" ]]; then
      kubectl -n "${NAMESPACE}" logs deploy/proxy --since=30m | grep -q 'CONNECT ml-models\.elastic\.co:443'
    fi
    echo "ELSER sparse embedding validation passed"
    ;;
  jina)
    ./scripts/start_jina_docker.sh
    JINA_BASE_URL="$(jina_base_url)"
    curl -fsS "${JINA_BASE_URL}/health" >/dev/null
    curl -fsS -H "Content-Type: application/json" "${JINA_BASE_URL}/v1/embeddings" \
      -d "{\"input\":[\"air gapped embedding service\"],\"model\":\"${JINA_MODEL}\"}" | grep -q '"embedding"'

    response="$(es_api POST "/_inference/text_embedding/${JINA_ENDPOINT_ID}" '{"input":["air gapped embedding service"]}')"
    echo "${response}" | grep -Eq '"embedding"|"text_embedding"'

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "${tmp_dir}"; stop_es_port_forward' EXIT

    export RESPONSE="${response}"
    ruby >"${tmp_dir}/query-vector.json" <<'RUBY'
require "json"

def find_embedding(value)
  case value
  when Hash
    value.each do |key, nested|
      return nested if (key == "embedding" || key == "text_embedding") && nested.is_a?(Array) && nested.all? { |item| item.is_a?(Numeric) }
      found = find_embedding(nested)
      return found if found
    end
  when Array
    value.each do |nested|
      found = find_embedding(nested)
      return found if found
    end
  end
  nil
end

embedding = find_embedding(JSON.parse(ENV.fetch("RESPONSE")))
raise "Unable to find embedding in inference response" unless embedding
puts JSON.generate(embedding)
RUBY

    dims="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV[0])).length' "${tmp_dir}/query-vector.json")"
    es_api DELETE "/jina-airgap-demo" >/dev/null || true
    es_api PUT "/jina-airgap-demo" "{
      \"mappings\": {
        \"properties\": {
          \"title\": { \"type\": \"text\" },
          \"body\": { \"type\": \"text\" },
          \"embedding\": {
            \"type\": \"dense_vector\",
            \"dims\": ${dims},
            \"index\": true,
            \"similarity\": \"cosine\"
          }
        }
      }
    }" >/dev/null

    make_doc() {
      local title="$1"
      local body="$2"
      local output="$3"
      local inference
      inference="$(es_api POST "/_inference/text_embedding/${JINA_ENDPOINT_ID}" "$(ruby -rjson -e 'puts JSON.generate({input: [ARGV[0]]})' "${body}")")"
      RESPONSE="${inference}" TITLE="${title}" BODY="${body}" ruby >"${output}" <<'RUBY'
require "json"

def find_embedding(value)
  case value
  when Hash
    value.each do |key, nested|
      return nested if (key == "embedding" || key == "text_embedding") && nested.is_a?(Array) && nested.all? { |item| item.is_a?(Numeric) }
      found = find_embedding(nested)
      return found if found
    end
  when Array
    value.each do |nested|
      found = find_embedding(nested)
      return found if found
    end
  end
  nil
end

embedding = find_embedding(JSON.parse(ENV.fetch("RESPONSE")))
raise "Unable to find embedding in inference response" unless embedding
puts JSON.generate({
  title: ENV.fetch("TITLE"),
  body: ENV.fetch("BODY"),
  embedding: embedding
})
RUBY
    }

    make_doc "Air-gapped Jina" "Use an external Jina embedding service with Elasticsearch inference for semantic document retrieval." "${tmp_dir}/doc1.json"
    make_doc "Unrelated" "A vegetable garden needs water and sunlight during the summer." "${tmp_dir}/doc2.json"

    es_api POST "/jina-airgap-demo/_doc/1?refresh=true" "$(cat "${tmp_dir}/doc1.json")" >/dev/null
    es_api POST "/jina-airgap-demo/_doc/2?refresh=true" "$(cat "${tmp_dir}/doc2.json")" >/dev/null

    ruby -rjson >"${tmp_dir}/search.json" <<RUBY
query = JSON.parse(File.read("${tmp_dir}/query-vector.json"))
puts JSON.generate({
  knn: {
    field: "embedding",
    query_vector: query,
    k: 1,
    num_candidates: 2
  },
  size: 1
})
RUBY

    search_response="$(es_api GET "/jina-airgap-demo/_search" "$(cat "${tmp_dir}/search.json")")"
    echo "${search_response}" | grep -q '"_id":"1"'
    echo "Jina embedding and semantic document validation passed"
    ;;
esac
