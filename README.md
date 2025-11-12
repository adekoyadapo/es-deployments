# Elastic Sample Deployments

Collection of Terraform configurations that prototype Elastic deployments across managed Kubernetes services, Minikube, and Elastic Cloud projects.

## Prerequisites

**Tooling**
- Machine: arm64 macOS host
- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) v1.5.7 (or newer)
- [terraform-docs](https://terraform-docs.io/) v0.20.0 for regenerating module documentation
- [minikube](https://minikube.sigs.k8s.io/) v1.34.0 with the [QEMU driver](https://minikube.sigs.k8s.io/docs/drivers/qemu/)

**Elastic stack components**
- ECK Operator 2.14.0
- Istio gateway 1.24.0 for the Istio-focused samples

## Repository Structure

**Elastic Cloud**
- [ec-cloud/es-observe](./ec-cloud/es-observe) – Bootstraps an Elastic Cloud observability project ready for ingest pipelines and dashboards.
- [ec-cloud/es-rally](./ec-cloud/es-rally) – Provisions an Elastic Cloud deployment tailored for Elastic Rally benchmarking scenarios.
- [ec-cloud/serverless](./ec-cloud/serverless) – Creates optional observability, search, and security serverless projects via the Elastic Cloud API.

**Azure AKS**
- [eck-aks-istio](./eck-aks-istio) – ECK on AKS fronted by Istio ingress gateway with Azure Storage snapshot integration.
- [eck-aks-istio-tiered](./eck-aks-istio-tiered) – Tiered AKS deployment combining Istio, multiple Elasticsearch tiers, and snapshot exports.

**Google Kubernetes Engine**
- [eck-gke-stack-monitoring/infra](./eck-gke-stack-monitoring/infra) – GKE infrastructure for the stack monitoring reference architecture.
- [eck-gke-stack-monitoring/deployments](./eck-gke-stack-monitoring/deployments) – ECK resources and Beats/Fleet assets layered on the stack-monitoring cluster.
- [eck-gke-uam/infra](./eck-gke-uam/infra) – Shared VPC and Autopilot-ready cluster assets for the user access monitoring scenario.
- [eck-gke-uam/deployments](./eck-gke-uam/deployments) – ECK components, Fleet integrations, and workloads that enable user access monitoring.
- [gke-autopilot](./gke-autopilot) – Placeholder for an upcoming GKE Autopilot example (currently empty).

**Amazon EKS**
- [eks-cluster](./eks-cluster) – Provisions the base EKS cluster and dependencies used by several Elastic-on-EKS experiments.

**Minikube core scenarios**
- [eck-minikube-istio](./eck-minikube-istio) – Local Istio + ECK stack with MetalLB-backed ingress paths.
- [eck-minikube-ccs](./eck-minikube-ccs) – Cross-cluster search topology spanning multiple Elasticsearch namespaces.
- [eck-minikube-tiered](./eck-minikube-tiered) – Tiered hot/warm Elasticsearch deployment with dedicated master and data node sets.

**Minikube advanced clusters**
- [eck-minikube-nodes](./eck-minikube-nodes) – Baseline multi-node Minikube cluster with operator bootstrap and sample stacks.
- [eck-minikube-nodes-snapshot](./eck-minikube-nodes-snapshot) – Snapshot-enabled cluster using 9.x snapshot artifacts and additional ML nodes.
- [eck-minikube-stack-monitoring](./eck-minikube-stack-monitoring) – Stack monitoring scenario that wires Beats and Fleet Server into ECK.

**Minikube observability add-ons**
- [eck-minikube-otel](./eck-minikube-otel) – OpenTelemetry collector pipelines wired into Elasticsearch and Elastic APM.
- [eck-minikube-uam](./eck-minikube-uam) – User access monitoring environment with scripted asset provisioning and audit trails.
