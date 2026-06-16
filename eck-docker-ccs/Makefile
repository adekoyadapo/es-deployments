SHELL := /bin/bash

MODE ?= api-key
ES_VERSION ?= 9.4.2
ECK_VERSION ?= 3.4.0
K3D_CLUSTER ?= eck-docker-ccs
NAMESPACE ?= ccs-lab
ECK_CLUSTER ?= main
REMOTE_ALIAS ?= remote-docker

export MODE
export ES_VERSION
export ECK_VERSION
export K3D_CLUSTER
export NAMESPACE
export ECK_CLUSTER
export REMOTE_ALIAS

.PHONY: help up down status logs test llm llm-remove clean certs check credentials creds ingress-hosts

help:
	@echo "Usage:"
	@echo "  make up MODE=api-key     Start ECK main cluster + Docker remote using API key auth on 9443"
	@echo "  make up MODE=cert        Start ECK main cluster + Docker remote using legacy cert auth on 9300"
	@echo "  make test MODE=api-key   Validate remote info, CCS, and CCR"
	@echo "  make llm                 Create an optional Kibana LLM connector and seed agent CCS docs"
	@echo "  make llm-remove          Remove the optional LLM connector, data view, and agent CCS docs"
	@echo "  make status              Show Kubernetes and Docker state"
	@echo "  make logs                Show recent ECK and Docker Elasticsearch logs"
	@echo "  make credentials         Print ECK and Docker URLs and credentials"
	@echo "  make ingress-hosts       Print detected sslip.io ingress hostnames"
	@echo "  make down                Delete the k3d cluster and stop Docker Compose"
	@echo "  make clean               Delete generated local certificates and runtime files"
	@echo ""
	@echo "Defaults:"
	@echo "  ES_VERSION=$(ES_VERSION)"
	@echo "  ECK_VERSION=$(ECK_VERSION)"
	@echo "  K3D_CLUSTER=$(K3D_CLUSTER)"
	@echo "  NAMESPACE=$(NAMESPACE)"
	@echo "  REMOTE_ALIAS=$(REMOTE_ALIAS)"

check:
	@./scripts/check_deps.sh

certs:
	@./scripts/generate_certs.sh

up: check certs
	@./scripts/up.sh

test: check
	@./scripts/test_ccs_ccr.sh

llm: check
	@./scripts/llm_setup.sh

llm-remove: check
	@./scripts/llm_remove.sh

status:
	@./scripts/status.sh

credentials creds:
	@./scripts/credentials.sh

ingress-hosts:
	@./scripts/ingress_hosts.sh

logs:
	@./scripts/logs.sh

down:
	@./scripts/down.sh

clean:
	@./scripts/clean.sh
