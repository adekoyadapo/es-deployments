#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
validate_mode
ensure_env_file
load_runtime_env

kubectl config use-context "k3d-${K3D_CLUSTER}" >/dev/null

MAIN_ELASTIC_PASSWORD="$(eck_password)"
export MAIN_ELASTIC_PASSWORD

LLM_CONNECTOR_ID="${LLM_CONNECTOR_ID:-ccs-lab-llm}"
MAIN_AGENT_INDEX="${MAIN_AGENT_INDEX:-agent-main-knowledge}"
REMOTE_AGENT_INDEX="${REMOTE_AGENT_INDEX:-agent-remote-knowledge}"
AGENT_DATA_VIEW_ID="${AGENT_DATA_VIEW_ID:-ccs-agent-knowledge}"

delete_kibana_resource() {
  local label="$1"
  local path="$2"

  if kibana_api DELETE "${path}" >/dev/null 2>&1; then
    echo "Deleted ${label}."
  else
    echo "${label} was not present or could not be deleted; continuing."
  fi
}

delete_index() {
  local cluster="$1"
  local index="$2"

  case "${cluster}" in
    main)
      if main_es_api DELETE "/${index}" >/dev/null 2>&1; then
        echo "Deleted main index ${index}."
      else
        echo "Main index ${index} was not present; continuing."
      fi
      ;;
    remote)
      if remote_es_api DELETE "/${index}" >/dev/null 2>&1; then
        echo "Deleted remote index ${index}."
      else
        echo "Remote index ${index} was not present; continuing."
      fi
      ;;
    *)
      die "Unsupported cluster ${cluster}"
      ;;
  esac
}

delete_inference_endpoint() {
  if main_es_api DELETE "/_inference/chat_completion/${LLM_CONNECTOR_ID}" >/dev/null 2>&1; then
    echo "Deleted Bedrock inference endpoint ${LLM_CONNECTOR_ID}."
  else
    echo "Bedrock inference endpoint ${LLM_CONNECTOR_ID} was not present; continuing."
  fi
}

main() {
  wait_for_main_api
  wait_for_main_kibana_api
  wait_for_remote

  delete_kibana_resource "Kibana connector ${LLM_CONNECTOR_ID}" "/api/actions/connector/${LLM_CONNECTOR_ID}"
  delete_inference_endpoint
  delete_kibana_resource "Kibana data view ${AGENT_DATA_VIEW_ID}" "/api/data_views/data_view/${AGENT_DATA_VIEW_ID}"
  delete_index main "${MAIN_AGENT_INDEX}"
  delete_index remote "${REMOTE_AGENT_INDEX}"

  echo "LLM setup removed."
}

main "$@"
