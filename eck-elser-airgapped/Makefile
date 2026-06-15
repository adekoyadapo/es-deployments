SHELL := /bin/bash

MODE ?= file
ES_VERSION ?= 9.4.2
ECK_VERSION ?= 3.4.0
NAMESPACE ?= elser-lab
CLUSTER_NAME ?= eck-elser-airgap
MODEL_ARTIFACTS_DIR ?= $(CURDIR)/artifacts/elser
MODEL_ARTIFACTS_NODE_PATH ?= /mnt/elser-models
ELSER_MODEL_ID ?= .elser_model_2
ELSER_ENDPOINT_ID ?= elser-airgap
JINA_MODEL ?= jina-embeddings-v5-text-small
JINA_IMAGE ?= ghcr.io/jina-ai/jina-airgap/jina-embeddings-v5-text-small:cpu
JINA_ENDPOINT_ID ?= jina-airgap
JINA_RUNTIME ?= cpu
JINA_PORT ?= 18080
JINA_CONTAINER_NAME ?= eck-elser-jina

export MODE
export ES_VERSION
export ECK_VERSION
export NAMESPACE
export CLUSTER_NAME
export MODEL_ARTIFACTS_DIR
export MODEL_ARTIFACTS_NODE_PATH
export ELSER_MODEL_ID
export ELSER_ENDPOINT_ID
export JINA_MODEL
export JINA_IMAGE
export JINA_ENDPOINT_ID
export JINA_RUNTIME
export JINA_PORT
export JINA_CONTAINER_NAME

.PHONY: help up down status logs test artifacts-check license port-forward clean-generated

help:
	@echo "Usage:"
	@echo "  make up MODE=file              Deploy ECK + ELSER using file-based model artifacts"
	@echo "  make up MODE=http              Deploy ECK + passwordless in-cluster HTTP artifact server"
	@echo "  make up MODE=jina              Deploy ECK + external amd64 Jina airgap Docker service"
	@echo "  make test MODE=file|http|jina  Validate the selected inference path"
	@echo "  make artifacts-check           Validate local cross-platform ELSER artifact files"
	@echo "  make license LICENSE_FILE=...  Apply a license JSON, or start trial if LICENSE_FILE is unset"
	@echo "  make status                    Show ECK and workload status"
	@echo "  make logs                      Show recent operator, Elasticsearch, Kibana, and Jina logs"
	@echo "  make port-forward              Print local port-forward commands"
	@echo "  make down                      Delete the local k3d cluster"
	@echo ""
	@echo "Defaults:"
	@echo "  ES_VERSION=$(ES_VERSION)"
	@echo "  ECK_VERSION=$(ECK_VERSION)"
	@echo "  MODEL_ARTIFACTS_DIR=$(MODEL_ARTIFACTS_DIR)"

up:
	@./scripts/validate_mode.sh
	@./scripts/validate_version.sh
	@if [ "$${MODE}" = "file" ] || [ "$${MODE}" = "http" ]; then ./scripts/check_artifacts.sh; fi
	@./scripts/create_cluster.sh
	@./scripts/install_eck.sh
	@./scripts/deploy_stack.sh
	@./scripts/wait_ready.sh
	@./scripts/apply_license.sh
	@./scripts/setup_inference.sh
	@echo ""
	@echo "Environment ready"
	@echo "Mode:          $${MODE}"
	@echo "Namespace:     $${NAMESPACE}"
	@echo "Stack version: $${ES_VERSION}"
	@echo "Kibana:        kubectl -n $${NAMESPACE} port-forward svc/kibana-kb-http 5601:5601"
	@echo "Elasticsearch: kubectl -n $${NAMESPACE} port-forward svc/elasticsearch-es-http 9200:9200"
	@echo "Elastic user:  elastic"
	@echo "Password:      kubectl -n $${NAMESPACE} get secret elasticsearch-es-elastic-user -o jsonpath='{.data.elastic}' | base64 -d; echo"

down:
	@./scripts/destroy_cluster.sh

status:
	@kubectl get nodes
	@kubectl -n elastic-system get pods
	@kubectl -n $${NAMESPACE} get elasticsearch,kibana,pods,svc
	@if [ "$${MODE}" = "jina" ]; then kubectl -n $${NAMESPACE} get hpa || true; fi

logs:
	@./scripts/logs.sh

test:
	@./scripts/validate_mode.sh
	@./scripts/test_inference.sh

artifacts-check:
	@./scripts/check_artifacts.sh

license:
	@./scripts/apply_license.sh

port-forward:
	@echo "Elasticsearch:"
	@echo "  kubectl -n $${NAMESPACE} port-forward svc/elasticsearch-es-http 9200:9200"
	@echo "Kibana:"
	@echo "  kubectl -n $${NAMESPACE} port-forward svc/kibana-kb-http 5601:5601"
	@if [ "$${MODE}" = "jina" ]; then echo "Jina:"; echo "  http://$$(./scripts/sslip_host.sh):$${JINA_PORT:-18080}"; fi

clean-generated:
	@rm -f manifests/elastic/eck-crds.yaml manifests/elastic/eck-operator.yaml
