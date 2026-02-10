SHELL := /bin/bash
.DEFAULT_GOAL := help

CLUSTER_NAME := es-mon
ES_PASSWORD := changeme
ELASTIC_VERSION ?= 8.19.11

# Detect IP for URL output
IP ?= $(shell ipconfig getifaddr en0 2>/dev/null || ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($$i=="src") print $$(i+1)}')
IP_DASHED := $(subst .,-,$(IP))

.PHONY: help setup teardown start stop status verify urls info \
        logs-mon-es logs-mon-kb logs-dev-es logs-dev-kb \
        logs-metricbeat logs-filebeat

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

setup: ## Run full setup (create cluster + deploy stacks)
	@ELASTIC_VERSION=$(ELASTIC_VERSION) bash setup.sh

teardown: ## Delete the k3d cluster
	k3d cluster delete $(CLUSTER_NAME)
	@echo "Cluster '$(CLUSTER_NAME)' deleted."

start: setup ## Alias for setup

stop: teardown ## Alias for teardown

status: ## Show pod status across all namespaces
	@echo "=== monitoring ==="
	@kubectl get pods -n monitoring -o wide 2>/dev/null || echo "Namespace not found"
	@echo ""
	@echo "=== dev ==="
	@kubectl get pods -n dev -o wide 2>/dev/null || echo "Namespace not found"

verify: ## Run health checks against all endpoints
	@echo "Checking endpoints..."
	@echo -n "  Monitoring ES: " && curl -sf -u elastic:$(ES_PASSWORD) http://mon-es.$(IP_DASHED).sslip.io/_cluster/health | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['status'])" 2>/dev/null || echo "UNREACHABLE"
	@echo -n "  Dev ES:        " && curl -sf -u elastic:$(ES_PASSWORD) http://dev-es.$(IP_DASHED).sslip.io/_cluster/health | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['status'])" 2>/dev/null || echo "UNREACHABLE"
	@echo -n "  Monitoring KB: " && curl -sf -o /dev/null -w "OK (HTTP %{http_code})" http://mon-kb.$(IP_DASHED).sslip.io/api/status 2>/dev/null || echo "UNREACHABLE"
	@echo ""
	@echo -n "  Dev KB:        " && curl -sf -o /dev/null -w "OK (HTTP %{http_code})" http://dev-kb.$(IP_DASHED).sslip.io/api/status 2>/dev/null || echo "UNREACHABLE"
	@echo ""
	@echo ""
	@echo "Monitoring indices:"
	@curl -sf -u elastic:$(ES_PASSWORD) 'http://mon-es.$(IP_DASHED).sslip.io/_cat/indices?v' 2>/dev/null || echo "  Could not fetch indices"

urls: ## Print access URLs
	@echo "═══════════════════════════════════════════════════════"
	@echo "  Access URLs"
	@echo "═══════════════════════════════════════════════════════"
	@echo "  Monitoring ES:     http://mon-es.$(IP_DASHED).sslip.io"
	@echo "  Monitoring Kibana: http://mon-kb.$(IP_DASHED).sslip.io"
	@echo "  Dev ES:            http://dev-es.$(IP_DASHED).sslip.io"
	@echo "  Dev Kibana:        http://dev-kb.$(IP_DASHED).sslip.io"
	@echo ""
	@echo "  Stack Monitoring:  http://mon-kb.$(IP_DASHED).sslip.io/app/monitoring"
	@echo "═══════════════════════════════════════════════════════"

info: urls ## Print access URLs + credentials
	@echo ""
	@echo "  Credentials:      elastic / $(ES_PASSWORD)"

logs-mon-es: ## Tail monitoring ES logs
	kubectl logs -f -n monitoring -l app=mon-es --tail=100

logs-mon-kb: ## Tail monitoring Kibana logs
	kubectl logs -f -n monitoring -l app=mon-kb --tail=100

logs-dev-es: ## Tail dev ES logs
	kubectl logs -f -n dev -l app=dev-es --tail=100

logs-dev-kb: ## Tail dev Kibana logs
	kubectl logs -f -n dev -l app=dev-kb --tail=100

logs-metricbeat: ## Tail Metricbeat logs
	kubectl logs -f -n dev -l app=metricbeat --tail=100

logs-filebeat: ## Tail Filebeat logs
	kubectl logs -f -n dev -l app=filebeat --tail=100
