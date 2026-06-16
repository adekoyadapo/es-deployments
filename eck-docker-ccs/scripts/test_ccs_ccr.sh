#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
validate_mode
ensure_env_file
load_runtime_env

kubectl config use-context "k3d-${K3D_CLUSTER}" >/dev/null
wait_for_remote
remote_es_api POST "/_license/start_trial?acknowledge=true" >/dev/null 2>&1 || true

MAIN_ELASTIC_PASSWORD="$(eck_password)"
export MAIN_ELASTIC_PASSWORD

main_es_api GET "/_cluster/health?wait_for_status=yellow&timeout=30s" >/dev/null
remote_es_api GET "/_cluster/health?wait_for_status=yellow&timeout=30s" >/dev/null

remote_info="$(main_es_api GET "/_remote/info")"
echo "${remote_info}" | jq -e --arg alias "${REMOTE_ALIAS}" '.[$alias].connected == true' >/dev/null

main_es_api DELETE "/main-products" >/dev/null 2>&1 || true
remote_es_api DELETE "/remote-products" >/dev/null 2>&1 || true
remote_es_api DELETE "/remote-leader" >/dev/null 2>&1 || true
main_es_api DELETE "/remote-leader-follower" >/dev/null 2>&1 || true

main_es_api PUT "/main-products" '{"settings":{"number_of_shards":1,"number_of_replicas":0},"mappings":{"properties":{"name":{"type":"keyword"},"description":{"type":"text"},"origin":{"type":"keyword"}}}}' >/dev/null
remote_es_api PUT "/remote-products" '{"settings":{"number_of_shards":1,"number_of_replicas":0},"mappings":{"properties":{"name":{"type":"keyword"},"description":{"type":"text"},"origin":{"type":"keyword"}}}}' >/dev/null
remote_es_api PUT "/remote-leader" '{"settings":{"number_of_shards":1,"number_of_replicas":0,"index.soft_deletes.enabled":true},"mappings":{"properties":{"message":{"type":"text"},"seq":{"type":"integer"}}}}' >/dev/null

main_es_api POST "/main-products/_doc/main-1?refresh=true" '{"name":"main-widget","description":"Document indexed into the ECK main cluster","origin":"main"}' >/dev/null
remote_es_api POST "/remote-products/_doc/remote-1?refresh=true" '{"name":"remote-widget","description":"Document indexed into the Docker remote cluster","origin":"remote"}' >/dev/null
remote_es_api POST "/remote-leader/_doc/leader-1?refresh=true" '{"message":"first replicated remote leader document","seq":1}' >/dev/null

ccs_response="$(main_es_api GET "/main-products,${REMOTE_ALIAS}:remote-products/_search" '{
  "query": { "match": { "description": "cluster" } },
  "sort": [ { "origin": "asc" } ],
  "size": 10
}')"
echo "${ccs_response}" | jq -e '.hits.total.value >= 2' >/dev/null
echo "CCS hits:"
echo "${ccs_response}" | jq -r '.hits.hits[] | [.["_index"], .["_id"], .["_source"].origin, .["_source"].name] | @tsv'

main_es_api PUT "/remote-leader-follower/_ccr/follow?wait_for_active_shards=1" "{
  \"remote_cluster\": \"${REMOTE_ALIAS}\",
  \"leader_index\": \"remote-leader\"
}" >/dev/null

remote_es_api POST "/remote-leader/_doc/leader-2?refresh=true" '{"message":"second replicated remote leader document","seq":2}' >/dev/null

for _ in $(seq 1 60); do
  follower_count="$(main_es_api GET "/remote-leader-follower/_count" | jq -r '.count')"
  if [[ "${follower_count}" -ge 2 ]]; then
    echo "CCR follower count: ${follower_count}"
    main_es_api GET "/remote-leader-follower/_search?sort=seq:asc" | jq -r '.hits.hits[] | [.["_id"], .["_source"].seq, .["_source"].message] | @tsv'
    echo "CCS and CCR validation passed"
    exit 0
  fi
  sleep 2
done

main_es_api GET "/remote-leader-follower/_ccr/info" | jq . >&2 || true
die "CCR follower did not receive the expected documents."
