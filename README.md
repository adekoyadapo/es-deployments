# Elastic Sample Deployments

Deployments to validate various Elastic Search cluster deployments in different scenarios, this will be populated accordingly.

## Prerequisite

### Tools version

- Machine - arm64 
- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) v1.5.7 - darwin
- minikube version: v1.34.0
    - with [Qemu](https://minikube.sigs.k8s.io/docs/drivers/qemu/)
- ECK Operator - 2.14.0

## ECK - Kubernetes Deployments

- Istio GW - 1.24.0
    - [ECK Minikube Istio](./eck-minikube-istio) with Metallb for LB IP allocation
    - [ECK AKS Istio](./eck-aks-istio)