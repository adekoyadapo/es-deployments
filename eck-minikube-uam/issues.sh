#!/bin/bash

# Elasticsearch Cluster Issues Simulator
# This script creates or cleans up various problematic scenarios in your local Elasticsearch cluster

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validate environment file exists before sourcing
ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: ${ENV_FILE} file not found${NC}"
    echo "Ensure ES_LOCAL_URL and ES_LOCAL_PASSWORD are defined there."
    exit 1
fi

# Load environment variables
source "$ENV_FILE"

# Set up authentication and validate required variables
ES_URL="${ES_LOCAL_URL:-}"
ES_USER="${ES_LOCAL_USER:-elastic}"
ES_PASS="${ES_LOCAL_PASSWORD:-}"

if [ -z "$ES_URL" ] || [ -z "$ES_PASS" ]; then
    echo -e "${RED}Error: ES_LOCAL_URL or ES_LOCAL_PASSWORD is not set in .env${NC}"
    echo "Please set both in ${ENV_FILE}"
    exit 1
fi

# Helper function to make Elasticsearch requests
es_request() {
    local method=$1
    local endpoint=$2
    local data=${3:-}

    if [ -z "$data" ]; then
        curl -k -sS --fail-with-body -X "$method" \
            -u "${ES_USER}:${ES_PASS}" \
            -H "Content-Type: application/json" \
            "${ES_URL}${endpoint}"
    else
        curl -k -sS --fail-with-body -X "$method" \
            -u "${ES_USER}:${ES_PASS}" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "${ES_URL}${endpoint}"
    fi
}

# Cleanup function
cleanup_cluster() {
    echo -e "${YELLOW}Running cleanup...${NC}"

    declare -a indices=("problematic-replicas" "red-index" "bad-template-test")
    declare -a index_templates=("my-bad-template" "bad-index-template")
    declare -a legacy_templates=("bad-legacy-template")
    declare -a component_templates=("bad-component-template")

    for idx in "${indices[@]}"; do
        echo "Deleting index: ${idx}"
        es_request DELETE "/${idx}" >/dev/null 2>&1 && echo -e "  ${GREEN}✓ Deleted${NC}" || echo -e "  ${YELLOW}⚠ Not found${NC}"
    done

    for tmpl in "${index_templates[@]}"; do
        echo "Deleting index template: ${tmpl}"
        es_request DELETE "/_index_template/${tmpl}" >/dev/null 2>&1 && echo -e "  ${GREEN}✓ Deleted${NC}" || echo -e "  ${YELLOW}⚠ Not found${NC}"
    done

    for tmpl in "${legacy_templates[@]}"; do
        echo "Deleting legacy template: ${tmpl}"
        es_request DELETE "/_template/${tmpl}" >/dev/null 2>&1 && echo -e "  ${GREEN}✓ Deleted${NC}" || echo -e "  ${YELLOW}⚠ Not found${NC}"
    done

    for tmpl in "${component_templates[@]}"; do
        echo "Deleting component template: ${tmpl}"
        es_request DELETE "/_component_template/${tmpl}" >/dev/null 2>&1 && echo -e "  ${GREEN}✓ Deleted${NC}" || echo -e "  ${YELLOW}⚠ Not found${NC}"
    done

    echo
    echo -e "${GREEN}✅ Cleanup complete!${NC}"
    exit 0
}

# Parse flags
if [[ "$1" == "--cleanup" || "$1" == "-c" ]]; then
    cleanup_cluster
fi

echo -e "${YELLOW}Elasticsearch Cluster Issues Simulator${NC}"
echo "======================================="
echo

# Additional connectivity validation
echo -e "${GREEN}Validating prerequisites...${NC}"

# Check if Elasticsearch is accessible with retry logic
echo "Testing Elasticsearch connectivity..."
attempts=0; max_attempts=3
until http_code=$(curl -k -sS -o /dev/null -w '%{http_code}' -u "${ES_USER}:${ES_PASS}" "${ES_URL}/_cluster/health") \
  && [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; do
  attempts=$((attempts+1))
  if [ $attempts -ge $max_attempts ]; then
    echo -e "${RED}Error: Cannot connect to Elasticsearch at ${ES_URL}${NC}"
    echo "HTTP status: ${http_code:-n/a}"
    exit 1
  fi
  echo "Attempt $attempts/$max_attempts failed, retrying in 2 seconds..."
  sleep 2
done

echo -e "${GREEN}✓ Prerequisites validated successfully${NC}"
echo

# Check cluster health first
echo -e "${GREEN}Checking initial cluster health...${NC}"
es_request GET "/_cluster/health?pretty" | grep -E "status|number_of_nodes"
echo

# --- Begin Issues Creation ---

# Issue 1: Create index with too many replicas
echo -e "${RED}Issue 1: Creating index with too many replicas${NC}"
es_request PUT "/problematic-replicas" '{
  "settings": { "number_of_shards": 3, "number_of_replicas": 2 }
}' | jq '.' 2>/dev/null || echo "Index created"

for i in {1..10}; do
    es_request POST "/problematic-replicas/_doc" "{
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",
      \"message\": \"Document $i with unassigned replica shards\",
      \"value\": $i
    }" >/dev/null
done

echo "Documents indexed successfully!"
es_request GET "/_cluster/health/problematic-replicas?pretty" | grep -E "status|unassigned_shards"
echo

# Issue 2: Problematic index template
echo -e "${RED}Issue 2: Creating problematic index template${NC}"
es_request PUT "/_index_template/my-bad-template" '{
  "index_patterns": ["bad-template*"],
  "template": {
    "mappings": {
      "properties": {
        "message": {
          "type": "text",
          "fields": {
            "keyword": { "type": "keyword" },
            "raw": { "type": "keyword", "ignore_above": 256 }
          }
        },
        "text": {
          "type": "text",
          "fields": { "text": { "type": "text" } }
        }
      }
    }
  }
}' >/dev/null && echo "Template created"

es_request PUT "/bad-template-test" >/dev/null && echo "Index created from bad template"
echo

# Issue 3: Legacy template
echo -e "${RED}Issue 3: Creating bad legacy template${NC}"
es_request PUT "/_template/bad-legacy-template" '{
  "index_patterns": ["bad-legacy-index-*"],
  "mappings": {
    "properties": {
      "message": {
        "type": "keyword",
        "fields": {
          "text": { "type": "keyword" },
          "raw": { "type": "keyword" }
        }
      }
    }
  }
}' >/dev/null && echo "Legacy template created"
echo

# Issue 4: Bad component template
echo -e "${RED}Issue 4: Creating bad component template${NC}"
es_request PUT "/_component_template/bad-component-template" '{
  "template": {
    "mappings": {
      "properties": {
        "message": {
          "type": "keyword",
          "fields": {
            "text": { "type": "keyword" },
            "raw": { "type": "keyword" }
          }
        }
      }
    }
  }
}' >/dev/null && echo "Component template created"
echo

# Issue 5: Bad index template with redundant keywords
echo -e "${RED}Issue 5: Creating bad index template${NC}"
es_request PUT "/_index_template/bad-index-template" '{
  "index_patterns": ["bad-index-*"],
  "template": {
    "mappings": {
      "properties": {
        "message": {
          "type": "keyword",
          "fields": {
            "text": { "type": "keyword" },
            "raw": { "type": "keyword" }
          }
        }
      }
    }
  }
}' >/dev/null && echo "Index template created"
echo

# Issue 6: Impossible allocation index
echo -e "${RED}Issue 6: Creating impossible allocation index${NC}"
es_request PUT "/red-index" '{
  "settings": {
    "index.routing.allocation.require.does_not_exist": "or_this",
    "number_of_replicas": 0
  }
}' >/dev/null && echo "Red index created"
echo

# Summary
echo -e "${YELLOW}Summary:${NC}"
echo "  1. problematic-replicas -> YELLOW (unassigned shards)"
echo "  2. red-index -> RED (allocation impossible)"
echo "  3. bad templates created (multi-field issues)"
echo
echo -e "${GREEN}Use './scriptname.sh --cleanup' to remove all test data.${NC}"