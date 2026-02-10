#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="es-mon"
ELASTIC_VERSION="${ELASTIC_VERSION:-8.19.11}"
ES_PASSWORD="changeme"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---------- Step 1: Detect IP ----------
detect_ip() {
    local ip
    if command -v ip &>/dev/null; then
        ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')
    fi
    if [[ -z "${ip:-}" ]]; then
        ip=$(ipconfig getifaddr en0 2>/dev/null || true)
    fi
    if [[ -z "${ip:-}" ]]; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
    fi
    if [[ -z "${ip:-}" ]]; then
        err "Could not detect IP address. Set INTERFACE_IP env var manually."
        exit 1
    fi
    echo "$ip"
}

IP="${INTERFACE_IP:-$(detect_ip)}"
IP_DASHED="${IP//./-}"
log "Detected IP: ${IP} (dashed: ${IP_DASHED})"
log "Elastic Stack version: ${ELASTIC_VERSION}"

MON_ES_HOST="mon-es.${IP_DASHED}.sslip.io"
MON_KB_HOST="mon-kb.${IP_DASHED}.sslip.io"
DEV_ES_HOST="dev-es.${IP_DASHED}.sslip.io"
DEV_KB_HOST="dev-kb.${IP_DASHED}.sslip.io"

# ---------- Step 2: Prerequisites check ----------
for cmd in k3d kubectl curl; do
    if ! command -v "$cmd" &>/dev/null; then
        err "$cmd is required but not installed."
        exit 1
    fi
done

# ---------- Step 3: Create k3d cluster ----------
if k3d cluster list 2>/dev/null | grep -q "${CLUSTER_NAME}"; then
    warn "Cluster '${CLUSTER_NAME}' already exists. Skipping creation."
else
    log "Creating k3d cluster '${CLUSTER_NAME}'..."
    k3d cluster create "${CLUSTER_NAME}" \
        --servers 1 --agents 2 \
        -p "80:80@loadbalancer" \
        -p "443:443@loadbalancer" \
        --wait
fi

kubectl config use-context "k3d-${CLUSTER_NAME}"
log "Cluster ready."

# ---------- Step 4: Wait for Traefik ----------
log "Waiting for Traefik deployment to be created by Helm..."
for i in $(seq 1 30); do
    if kubectl get deployment traefik -n kube-system &>/dev/null; then
        break
    fi
    sleep 2
done
log "Waiting for Traefik to be ready..."
kubectl wait --for=condition=available deployment/traefik \
    -n kube-system --timeout=120s
log "Traefik is ready."

# ---------- Helper: Substitute IP in ingress manifests ----------
apply_with_ip() {
    local file="$1"
    sed "s/IP_PLACEHOLDER/${IP_DASHED}/g" "$file" | kubectl apply -f -
}

# ---------- Helper: Substitute Elastic Stack image versions ----------
apply_with_version() {
    local file="$1"
    # Replace all docker.elastic.co image tags with the desired version
    sed -E "s#(docker\\.elastic\\.co/[^:]+):[0-9]+\\.[0-9]+\\.[0-9]+#\\1:${ELASTIC_VERSION}#g" "$file" | kubectl apply -f -
}

# ---------- Helper: Wait for ES health (with auth) ----------
wait_for_es() {
    local svc="$1" ns="$2" max_wait="${3:-180}"
    log "Waiting for ES (${svc}.${ns}) to be healthy..."
    local elapsed=0
    while (( elapsed < max_wait )); do
        local status
        status=$(kubectl exec -n "$ns" \
            "$(kubectl get pod -n "$ns" -l app="${svc}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)" \
            -- curl -s -u "elastic:${ES_PASSWORD}" "http://localhost:9200/_cluster/health" 2>/dev/null \
            | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || true)
        if [[ "$status" == "green" || "$status" == "yellow" ]]; then
            log "ES ${svc}.${ns} is healthy (status: ${status})"
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        printf '.'
    done
    echo
    err "ES ${svc}.${ns} did not become healthy within ${max_wait}s"
    return 1
}

# ---------- Helper: Set built-in user password ----------
set_es_password() {
    local pod="$1" ns="$2" user="$3" pass="$4"
    log "Setting password for user '${user}' on ${pod}..."
    kubectl exec -n "$ns" "$pod" -- \
        curl -sf -X POST -u "elastic:${ES_PASSWORD}" \
        -H 'Content-Type: application/json' \
        "http://localhost:9200/_security/user/${user}/_password" \
        -d "{\"password\":\"${pass}\"}" >/dev/null 2>&1
    log "Password set for '${user}'."
}

# ---------- Step 5: Deploy Monitoring stack ----------
log "Deploying monitoring namespace and Elasticsearch..."
kubectl apply -f "${SCRIPT_DIR}/manifests/monitoring/namespace.yaml"
apply_with_version "${SCRIPT_DIR}/manifests/monitoring/elasticsearch.yaml"

log "Waiting for monitoring ES pod to be ready..."
kubectl wait --for=condition=ready pod -l app=mon-es \
    -n monitoring --timeout=300s

wait_for_es "mon-es" "monitoring"

# Set kibana_system password on monitoring ES
MON_ES_POD=$(kubectl get pod -n monitoring -l app=mon-es -o jsonpath='{.items[0].metadata.name}')
set_es_password "$MON_ES_POD" "monitoring" "kibana_system" "${ES_PASSWORD}"

# Now deploy monitoring Kibana (needs kibana_system password set first)
log "Deploying monitoring Kibana..."
apply_with_version "${SCRIPT_DIR}/manifests/monitoring/kibana.yaml"

log "Applying monitoring ingress..."
apply_with_ip "${SCRIPT_DIR}/manifests/monitoring/ingress.yaml"

# ---------- Step 6: Deploy Dev stack ----------
log "Deploying dev namespace and Elasticsearch..."
kubectl apply -f "${SCRIPT_DIR}/manifests/dev/namespace.yaml"
apply_with_version "${SCRIPT_DIR}/manifests/dev/elasticsearch.yaml"

log "Waiting for dev ES pod to be ready..."
kubectl wait --for=condition=ready pod -l app=dev-es \
    -n dev --timeout=300s

wait_for_es "dev-es" "dev"

# Set kibana_system password on dev ES
DEV_ES_POD=$(kubectl get pod -n dev -l app=dev-es -o jsonpath='{.items[0].metadata.name}')
set_es_password "$DEV_ES_POD" "dev" "kibana_system" "${ES_PASSWORD}"

# Now deploy dev Kibana
log "Deploying dev Kibana..."
apply_with_version "${SCRIPT_DIR}/manifests/dev/kibana.yaml"

log "Applying dev ingress..."
apply_with_ip "${SCRIPT_DIR}/manifests/dev/ingress.yaml"

# ---------- Step 7: Deploy Beats ----------
log "Deploying Metricbeat and Filebeat..."
apply_with_version "${SCRIPT_DIR}/manifests/beats/metricbeat.yaml"
apply_with_version "${SCRIPT_DIR}/manifests/beats/filebeat.yaml"

log "Waiting for Beats pods to be ready..."
kubectl wait --for=condition=ready pod -l app=metricbeat \
    -n dev --timeout=120s
kubectl wait --for=condition=ready pod -l app=filebeat \
    -n dev --timeout=120s

# ---------- Step 8: Wait for Kibana instances ----------
log "Waiting for monitoring Kibana to be ready..."
kubectl wait --for=condition=ready pod -l app=mon-kb \
    -n monitoring --timeout=300s
log "Waiting for dev Kibana to be ready..."
kubectl wait --for=condition=ready pod -l app=dev-kb \
    -n dev --timeout=300s

# ---------- Step 9: Verification ----------
log "Running verification checks..."
echo ""

verify_ok=true

# Check monitoring ES
if curl -sf -u "elastic:${ES_PASSWORD}" "http://${MON_ES_HOST}/_cluster/health" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Monitoring ES reachable at http://${MON_ES_HOST}"
else
    echo -e "  ${RED}✗${NC} Monitoring ES NOT reachable at http://${MON_ES_HOST}"
    verify_ok=false
fi

# Check dev ES
if curl -sf -u "elastic:${ES_PASSWORD}" "http://${DEV_ES_HOST}/_cluster/health" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Dev ES reachable at http://${DEV_ES_HOST}"
else
    echo -e "  ${RED}✗${NC} Dev ES NOT reachable at http://${DEV_ES_HOST}"
    verify_ok=false
fi

# Check monitoring Kibana
if curl -sf "http://${MON_KB_HOST}/api/status" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Monitoring Kibana reachable at http://${MON_KB_HOST}"
else
    echo -e "  ${YELLOW}~${NC} Monitoring Kibana may still be starting at http://${MON_KB_HOST}"
fi

# Check dev Kibana
if curl -sf "http://${DEV_KB_HOST}/api/status" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Dev Kibana reachable at http://${DEV_KB_HOST}"
else
    echo -e "  ${YELLOW}~${NC} Dev Kibana may still be starting at http://${DEV_KB_HOST}"
fi

# Wait a moment for monitoring data to flow, then check indices
sleep 10
echo ""
log "Monitoring indices on monitoring cluster:"
curl -sf -u "elastic:${ES_PASSWORD}" "http://${MON_ES_HOST}/_cat/indices/.monitoring-*,.ds-.monitoring-*?v&h=index,docs.count" 2>/dev/null || echo "  Could not fetch indices yet"

# Check dev cluster has NO monitoring indices
echo ""
log "Checking dev cluster has no monitoring indices..."
dev_mon_indices=$(curl -sf -u "elastic:${ES_PASSWORD}" "http://${DEV_ES_HOST}/_cat/indices/.monitoring-*?h=index" 2>/dev/null || true)
if [[ -z "$dev_mon_indices" ]]; then
    echo -e "  ${GREEN}✓${NC} Dev cluster has no .monitoring-* indices (correct!)"
else
    echo -e "  ${RED}✗${NC} Dev cluster has unexpected monitoring indices: ${dev_mon_indices}"
fi

# Check pods
echo ""
log "Pod status:"
kubectl get pods -n monitoring
echo ""
kubectl get pods -n dev

# ---------- Step 10: Print URLs ----------
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Access URLs${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "  Monitoring ES:     http://${MON_ES_HOST}"
echo -e "  Monitoring Kibana: http://${MON_KB_HOST}"
echo -e "  Dev ES:            http://${DEV_ES_HOST}"
echo -e "  Dev Kibana:        http://${DEV_KB_HOST}"
echo -e ""
echo -e "  ${YELLOW}Stack Monitoring:${NC} http://${MON_KB_HOST}/app/monitoring"
echo -e ""
echo -e "  ${YELLOW}Credentials:${NC}      elastic / ${ES_PASSWORD}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

if [[ "$verify_ok" == "true" ]]; then
    log "Setup complete!"
else
    warn "Setup completed with warnings. Some endpoints may need more time to start."
fi
