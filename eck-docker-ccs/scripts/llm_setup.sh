#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
validate_mode
ensure_env_file
load_runtime_env

kubectl config use-context "k3d-${K3D_CLUSTER}" >/dev/null

MAIN_ELASTIC_PASSWORD="$(eck_password)"
export MAIN_ELASTIC_PASSWORD

LLM_PROVIDER="${LLM_PROVIDER:-ollama}"
LLM_CONNECTOR_ID="${LLM_CONNECTOR_ID:-ccs-lab-llm}"
LLM_CONNECTOR_NAME="${LLM_CONNECTOR_NAME:-CCS Lab LLM}"
LLM_MODEL="${LLM_MODEL:-}"
LLM_API_URL="${LLM_API_URL:-}"
LLM_API_KEY="${LLM_API_KEY:-}"
LLM_VALIDATE="${LLM_VALIDATE:-true}"
LLM_DOC_COUNT="${LLM_DOC_COUNT:-120}"

MAIN_AGENT_INDEX="${MAIN_AGENT_INDEX:-agent-main-knowledge}"
REMOTE_AGENT_INDEX="${REMOTE_AGENT_INDEX:-agent-remote-knowledge}"
AGENT_DATA_VIEW_ID="${AGENT_DATA_VIEW_ID:-ccs-agent-knowledge}"

OPENAI_API_KEY="${OPENAI_API_KEY:-}"
OPENAI_MODEL="${OPENAI_MODEL:-gpt-4o-mini}"
OPENAI_API_URL="${OPENAI_API_URL:-https://api.openai.com/v1/chat/completions}"

OLLAMA_MODEL="${OLLAMA_MODEL:-}"
OLLAMA_API_KEY="${OLLAMA_API_KEY:-ollama}"
OLLAMA_API_URL="${OLLAMA_API_URL:-http://${HOST_IP}:11434/v1/chat/completions}"

AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-${aws_access_key_id:-}}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-${aws_secret_access_key:-}}"
AWS_REGION="${AWS_REGION:-us-east-1}"
BEDROCK_MODEL="${BEDROCK_MODEL:-us.anthropic.claude-sonnet-4-5-20250929-v1:0}"
BEDROCK_API_URL="${BEDROCK_API_URL:-https://bedrock-runtime.${AWS_REGION}.amazonaws.com}"
BEDROCK_PROVIDER="${BEDROCK_PROVIDER:-anthropic}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_value() {
  local name="$1"
  local value="$2"
  [[ -n "${value}" ]] || die "Missing required environment value: ${name}"
}

provider_key() {
  printf '%s' "${LLM_PROVIDER}" | tr '[:upper:]' '[:lower:]' | tr '_' '-'
}

detect_ollama_model() {
  local tags_url model
  tags_url="${OLLAMA_TAGS_URL:-http://${HOST_IP}:11434/api/tags}"
  model="$(curl -s --max-time 3 --noproxy "*" "${tags_url}" | jq -r '.models[0].name // empty' 2>/dev/null || true)"
  printf '%s' "${model}"
}

resolve_llm_provider() {
  local provider
  provider="$(provider_key)"

  case "${provider}" in
    ollama)
      LLM_MODEL="${LLM_MODEL:-${OLLAMA_MODEL}}"
      if [[ -z "${LLM_MODEL}" ]]; then
        LLM_MODEL="$(detect_ollama_model)"
      fi
      LLM_API_URL="${LLM_API_URL:-${OLLAMA_API_URL}}"
      LLM_API_KEY="${LLM_API_KEY:-${OLLAMA_API_KEY}}"
      require_value OLLAMA_API_URL "${LLM_API_URL}"
      require_value "LLM_MODEL or OLLAMA_MODEL, or a reachable Ollama /api/tags response" "${LLM_MODEL}"
      LLM_CONNECTOR_TYPE=".gen-ai"
      LLM_API_PROVIDER="Other"
      ;;
    openai|openai-compatible|other)
      if [[ "${provider}" == "openai" ]]; then
        LLM_MODEL="${LLM_MODEL:-${OPENAI_MODEL}}"
        LLM_API_URL="${LLM_API_URL:-${OPENAI_API_URL}}"
        LLM_API_KEY="${LLM_API_KEY:-${OPENAI_API_KEY}}"
        require_value OPENAI_API_KEY "${LLM_API_KEY}"
        require_value LLM_MODEL "${LLM_MODEL}"
        LLM_API_PROVIDER="OpenAI"
      else
        LLM_MODEL="${LLM_MODEL:-${OPENAI_MODEL}}"
        LLM_API_URL="${LLM_API_URL:-${OPENAI_API_URL}}"
        LLM_API_KEY="${LLM_API_KEY:-${OPENAI_API_KEY}}"
        require_value LLM_API_URL "${LLM_API_URL}"
        require_value LLM_MODEL "${LLM_MODEL}"
        require_value LLM_API_KEY "${LLM_API_KEY}"
        LLM_API_PROVIDER="Other"
      fi
      LLM_CONNECTOR_TYPE=".gen-ai"
      ;;
    bedrock|aws|aws-bedrock)
      LLM_MODEL="${LLM_MODEL:-${BEDROCK_MODEL}}"
      require_value AWS_ACCESS_KEY_ID "${AWS_ACCESS_KEY_ID}"
      require_value AWS_SECRET_ACCESS_KEY "${AWS_SECRET_ACCESS_KEY}"
      require_value AWS_REGION "${AWS_REGION}"
      require_value BEDROCK_PROVIDER "${BEDROCK_PROVIDER}"
      LLM_CONNECTOR_TYPE=".bedrock-inference"
      ;;
    *)
      die "Unsupported LLM_PROVIDER=${LLM_PROVIDER}. Use ollama, openai, openai-compatible, or bedrock."
      ;;
  esac
}

connector_body() {
  case "${LLM_CONNECTOR_TYPE}" in
    .gen-ai)
      jq -nc \
        --arg name "${LLM_CONNECTOR_NAME}" \
        --arg provider "${LLM_API_PROVIDER}" \
        --arg api_url "${LLM_API_URL}" \
        --arg model "${LLM_MODEL}" \
        --arg api_key "${LLM_API_KEY}" \
        '{name:$name, connector_type_id:".gen-ai", config:{apiProvider:$provider, apiUrl:$api_url, defaultModel:$model}, secrets:{apiKey:$api_key}}'
      ;;
    .bedrock)
      jq -nc \
        --arg name "${LLM_CONNECTOR_NAME}" \
        --arg api_url "${BEDROCK_API_URL}" \
        --arg model "${LLM_MODEL}" \
        --arg region "${AWS_REGION}" \
        --arg access_key "${AWS_ACCESS_KEY_ID}" \
        --arg secret "${AWS_SECRET_ACCESS_KEY}" \
        '{name:$name, connector_type_id:".bedrock", config:{apiUrl:$api_url, defaultModel:$model, region:$region}, secrets:{accessKey:$access_key, secret:$secret}}'
      ;;
    .bedrock-inference)
      jq -nc \
        --arg model "${LLM_MODEL}" \
        --arg region "${AWS_REGION}" \
        --arg provider "${BEDROCK_PROVIDER}" \
        --arg access_key "${AWS_ACCESS_KEY_ID}" \
        --arg secret_key "${AWS_SECRET_ACCESS_KEY}" \
        '{service:"amazonbedrock", service_settings:{access_key:$access_key, secret_key:$secret_key, region:$region, model:$model, provider:$provider}}'
      ;;
    *)
      die "Internal error: unsupported connector type ${LLM_CONNECTOR_TYPE:-unset}"
      ;;
  esac
}

create_bedrock_inference_endpoint() {
  local body="$1"
  local response status reason

  kibana_api DELETE "/api/actions/connector/${LLM_CONNECTOR_ID}" >/dev/null 2>&1 || true
  main_es_api DELETE "/_inference/chat_completion/${LLM_CONNECTOR_ID}" >/dev/null 2>&1 || true

  if ! response="$(main_es_api PUT "/_inference/chat_completion/${LLM_CONNECTOR_ID}?timeout=30s" "${body}")"; then
    printf '%s\n' "${response}" >&2
    die "Bedrock inference endpoint creation request failed."
  fi

  status="$(echo "${response}" | jq -r '.error.type // empty')"
  if [[ -n "${status}" ]]; then
    reason="$(echo "${response}" | jq -r '.error.reason // .error.root_cause[0].reason // "unknown inference endpoint creation error"')"
    die "Bedrock inference endpoint creation failed: ${reason}"
  fi

  echo "${response}" | jq -r '"Created inference endpoint \(.inference_id) (\(.service)/\(.task_type))"'
}

create_llm_connector() {
  local body="$1"
  local response status message
  kibana_api DELETE "/api/actions/connector/${LLM_CONNECTOR_ID}" >/dev/null 2>&1 || true
  if ! response="$(kibana_api POST "/api/actions/connector/${LLM_CONNECTOR_ID}" "${body}")"; then
    printf '%s\n' "${response}" >&2
    die "LLM connector creation request failed."
  fi

  if ! echo "${response}" | jq . >/dev/null 2>&1; then
    printf '%s\n' "${response}" >&2
    die "LLM connector creation returned a non-JSON response."
  fi

  status="$(echo "${response}" | jq -r '.statusCode // empty')"
  if [[ -n "${status}" ]]; then
    message="$(echo "${response}" | jq -r '.message // "unknown connector creation error"')"
    die "LLM connector creation failed: ${message}"
  fi

  echo "${response}" | jq -r '"Created connector \(.id) (\(.connector_type_id))"'
}

create_llm_connection() {
  local body="$1"

  case "${LLM_CONNECTOR_TYPE}" in
    .bedrock-inference)
      create_bedrock_inference_endpoint "${body}"
      ;;
    *)
      create_llm_connector "${body}"
      ;;
  esac
}

execute_llm_connector() {
  local provider request_body response status message
  provider="$(provider_key)"

  if [[ "${LLM_VALIDATE}" != "true" ]]; then
    echo "LLM connector execution skipped because LLM_VALIDATE=${LLM_VALIDATE}"
    return 0
  fi

  if [[ "${LLM_CONNECTOR_TYPE}" == ".bedrock-inference" ]]; then
    request_body="$(jq -nc '{messages:[{role:"user", content:"Reply with the words ccs llm ready."}], max_completion_tokens:32}')"
    echo "Validating Bedrock inference endpoint execution..."
    if ! response="$(main_es_api POST "/_inference/chat_completion/${LLM_CONNECTOR_ID}/_stream?timeout=60s" "${request_body}")"; then
      printf '%s\n' "${response}" >&2
      die "Bedrock inference endpoint execution request failed."
    fi
    printf '%s\n' "${response}" | sed -n '1,20p'
    if ! printf '%s\n' "${response}" | grep -Fq 'data: [DONE]'; then
      die "Bedrock inference endpoint stream did not complete."
    fi
    return 0
  fi

  case "${provider}" in
    bedrock|aws|aws-bedrock)
      request_body="$(jq -nc \
        --arg model "${LLM_MODEL}" \
        '{params:{subAction:"run", subActionParams:{body:({prompt:"Human: Reply with the words ccs llm ready.\n\nAssistant:", max_tokens_to_sample:32, stop_sequences:["\n\nHuman:"]}|tojson), model:$model}}}')"
      ;;
    *)
      request_body="$(jq -nc \
        --arg model "${LLM_MODEL}" \
        '{params:{subAction:"run", subActionParams:{body:({model:$model, messages:[{role:"user", content:"Reply with the words ccs llm ready."}], max_tokens:32}|tojson)}}}')"
      ;;
  esac

  echo "Validating LLM connector execution..."
  if ! response="$(kibana_api POST "/api/actions/connector/${LLM_CONNECTOR_ID}/_execute" "${request_body}")"; then
    printf '%s\n' "${response}" >&2
    die "LLM connector execution request failed."
  fi

  if echo "${response}" | jq . >/dev/null 2>&1; then
    echo "${response}" | jq .
    status="$(echo "${response}" | jq -r '.status // empty')"
    if [[ "${status}" == "error" ]]; then
      message="$(echo "${response}" | jq -r '.service_message // .message // "unknown connector execution error"')"
      die "LLM connector execution failed: ${message}"
    fi
  else
    printf '%s\n' "${response}" >&2
    die "LLM connector execution returned a non-JSON response."
  fi
}

index_mapping() {
  jq -nc '{
    settings:{number_of_shards:1, number_of_replicas:0},
    mappings:{properties:{
      cluster:{type:"keyword"},
      doc_id:{type:"keyword"},
      topic:{type:"keyword"},
      scenario:{type:"keyword"},
      title:{type:"text", fields:{keyword:{type:"keyword"}}},
      body:{type:"text"},
      validation_hint:{type:"text"},
      sequence:{type:"integer"},
      ingested_at:{type:"date"}
    }}
  }'
}

generate_bulk_file() {
  local file="$1"
  local index="$2"
  local cluster="$3"
  local prefix="$4"
  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  : >"${file}"

  for i in $(seq 1 "${LLM_DOC_COUNT}"); do
    local topic scenario title body hint id
    case $((i % 6)) in
      0) topic="inventory"; scenario="regional availability" ;;
      1) topic="orders"; scenario="fulfillment status" ;;
      2) topic="support"; scenario="case triage" ;;
      3) topic="security"; scenario="access review" ;;
      4) topic="observability"; scenario="service health" ;;
      *) topic="finance"; scenario="billing audit" ;;
    esac

    id="${prefix}-${i}"
    title="${cluster} ${topic} document ${i}"
    body="${cluster} sample record ${i} for ${scenario}. This content is unique to the ${cluster} cluster and is intended for cross cluster search agent testing."
    hint="Search for ${topic}, ${scenario}, ${cluster}, or ${prefix}-${i} to verify CCS coverage."

    jq -nc --arg index "${index}" --arg id "${id}" '{index:{_index:$index, _id:$id}}' >>"${file}"
    jq -nc \
      --arg cluster "${cluster}" \
      --arg id "${id}" \
      --arg topic "${topic}" \
      --arg scenario "${scenario}" \
      --arg title "${title}" \
      --arg body "${body}" \
      --arg hint "${hint}" \
      --arg now "${now}" \
      --argjson sequence "${i}" \
      '{cluster:$cluster, doc_id:$id, topic:$topic, scenario:$scenario, title:$title, body:$body, validation_hint:$hint, sequence:$sequence, ingested_at:$now}' >>"${file}"
  done
}

seed_agent_docs() {
  [[ "${LLM_DOC_COUNT}" =~ ^[0-9]+$ ]] || die "LLM_DOC_COUNT must be a number."
  (( LLM_DOC_COUNT >= 100 )) || die "LLM_DOC_COUNT must be 100 or more."

  mkdir -p "${RUNTIME_DIR}"
  local main_bulk="${RUNTIME_DIR}/llm-main-agent-docs.ndjson"
  local remote_bulk="${RUNTIME_DIR}/llm-remote-agent-docs.ndjson"
  local mapping
  mapping="$(index_mapping)"

  echo "Seeding ${LLM_DOC_COUNT} main-cluster docs into ${MAIN_AGENT_INDEX}..."
  main_es_api DELETE "/${MAIN_AGENT_INDEX}" >/dev/null 2>&1 || true
  main_es_api PUT "/${MAIN_AGENT_INDEX}" "${mapping}" >/dev/null
  generate_bulk_file "${main_bulk}" "${MAIN_AGENT_INDEX}" "main-eck" "main"
  main_es_api POST "/_bulk?refresh=true" "$(cat "${main_bulk}")"$'\n' >/dev/null

  echo "Seeding ${LLM_DOC_COUNT} remote-cluster docs into ${REMOTE_AGENT_INDEX}..."
  remote_es_api DELETE "/${REMOTE_AGENT_INDEX}" >/dev/null 2>&1 || true
  remote_es_api PUT "/${REMOTE_AGENT_INDEX}" "${mapping}" >/dev/null
  generate_bulk_file "${remote_bulk}" "${REMOTE_AGENT_INDEX}" "remote-docker" "remote"
  remote_es_api POST "/_bulk?refresh=true" "$(cat "${remote_bulk}")"$'\n' >/dev/null
}

refresh_api_key_remote_access() {
  local encoded

  if [[ "${MODE}" != "api-key" ]]; then
    return 0
  fi

  echo "Refreshing cross-cluster API key access for ${REMOTE_AGENT_INDEX}..."
  encoded="$(remote_es_api POST "/_security/cross_cluster/api_key" "$(jq -nc \
    --arg remote_agent_index "${REMOTE_AGENT_INDEX}" \
    '{
      name:"eck-docker-ccs-agent-docs",
      access:{
        search:[
          {names:["remote-products", "remote-leader", $remote_agent_index]}
        ],
        replication:[
          {names:["remote-leader"]}
        ]
      }
    }')" | jq -r '.encoded')"
  [[ -n "${encoded}" && "${encoded}" != "null" ]] || die "Failed to create cross-cluster API key for agent docs"

  kubectl -n "${NAMESPACE}" create secret generic remote-api-keys \
    --from-literal="cluster.remote.${REMOTE_ALIAS}.credentials=${encoded}" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null

  kubectl -n "${NAMESPACE}" rollout restart statefulset "${ECK_CLUSTER}-es-default" >/dev/null
  kubectl -n "${NAMESPACE}" delete pod "${ECK_CLUSTER}-es-default-0" --wait=false >/dev/null 2>&1 || true
  wait_for_eck
  wait_for_main_api
  wait_for_main_kibana_api
  wait_for_remote_connection
}

create_agent_data_view() {
  local title="${MAIN_AGENT_INDEX},${REMOTE_ALIAS}:${REMOTE_AGENT_INDEX}"
  local body
  body="$(jq -nc --arg id "${AGENT_DATA_VIEW_ID}" --arg title "${title}" \
    '{data_view:{id:$id, title:$title, name:"CCS Agent Knowledge", timeFieldName:"ingested_at"}}')"

  kibana_api POST "/api/data_views/data_view" "${body}" >/dev/null 2>&1 || true
  echo "Kibana data view target: ${title}"
}

validate_agent_ccs() {
  local expected=$((LLM_DOC_COUNT * 2))
  local response count
  response="$(main_es_api GET "/${MAIN_AGENT_INDEX},${REMOTE_ALIAS}:${REMOTE_AGENT_INDEX}/_search" "$(jq -nc '{track_total_hits:true, size:6, query:{match:{body:"cross cluster search agent testing"}}, sort:[{cluster:{order:"asc"}},{sequence:{order:"asc"}}]}')")"
  count="$(echo "${response}" | jq -r '.hits.total.value')"
  [[ "${count}" -ge "${expected}" ]] || die "Expected at least ${expected} CCS docs, got ${count}."

  echo "Agent CCS validation hits: ${count}"
  echo "${response}" | jq -r '.hits.hits[] | [.["_index"], .["_id"], .["_source"].cluster, .["_source"].topic, .["_source"].sequence] | @tsv'
}

main() {
  require_cmd jq
  require_cmd curl

  wait_for_main_api
  wait_for_main_kibana_api
  wait_for_remote
  wait_for_remote_connection

  resolve_llm_provider
  body="$(connector_body)"
  create_llm_connection "${body}"
  seed_agent_docs
  refresh_api_key_remote_access
  create_agent_data_view
  validate_agent_ccs
  execute_llm_connector

  echo "LLM setup complete."
}

main "$@"
