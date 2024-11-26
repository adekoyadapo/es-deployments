# eck-minikube-istio

## Sample deployments with Istio - non-ssl and Elastic Search ingress

## Deployment

```bash
terraform init
terraform plan
terraform apply
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_external"></a> [external](#requirement\_external) | 2.3.3 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.10.1 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0.2 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.22.0 |
| <a name="requirement_minikube"></a> [minikube](#requirement\_minikube) | 0.4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_external"></a> [external](#provider\_external) | 2.3.3 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 2.10.1 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 2.0.2 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 2.22.0 |
| <a name="provider_minikube"></a> [minikube](#provider\_minikube) | 0.4.0 |
| <a name="provider_time"></a> [time](#provider\_time) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.gateway](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.main](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.sec](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.eck](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.metallb](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.namespace](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [minikube_cluster.cluster](https://registry.terraform.io/providers/scott-the-programmer/minikube/0.4.0/docs/resources/cluster) | resource |
| [time_sleep.wait](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [external_external.getip](https://registry.terraform.io/providers/hashicorp/external/2.3.3/docs/data-sources/external) | data source |
| [kubernetes_resource.eck_password](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/resource) | data source |
| [kubernetes_resource.gateway](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/resource) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_image"></a> [cluster\_image](#input\_cluster\_image) | Cluster iamge | `string` | `"rancher/k3s:v1.30.4-k3s1"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | cluster\_name | `string` | `"demo"` | no |
| <a name="input_dir"></a> [dir](#input\_dir) | ECK dir | `string` | `"quickstart"` | no |
| <a name="input_helm_release"></a> [helm\_release](#input\_helm\_release) | Helm realease deployment | <pre>map(object({<br/>    repository       = string<br/>    chart            = string<br/>    namespace        = optional(string, "default")<br/>    values           = optional(list(string), [])<br/>    create_namespace = optional(bool, true)<br/>    version          = optional(string)<br/>    wait             = optional(bool, true)<br/>    is_main          = optional(bool, true)<br/>    set_values = optional(list(object({<br/>      name  = string<br/>      value = string<br/>    })), [])<br/>  }))</pre> | <pre>{<br/>  "cert-manager": {<br/>    "chart": "cert-manager",<br/>    "create_namespace": true,<br/>    "namespace": "cert-manager",<br/>    "repository": "https://charts.jetstack.io",<br/>    "set_values": [<br/>      {<br/>        "name": "crds.enabled",<br/>        "value": true<br/>      }<br/>    ],<br/>    "version": "1.15.3"<br/>  },<br/>  "elastic-operator": {<br/>    "chart": "eck-operator",<br/>    "create_namespace": true,<br/>    "namespace": "elastic-system",<br/>    "repository": "https://helm.elastic.co",<br/>    "version": "2.14.0"<br/>  }<br/>}</pre> | no |
| <a name="input_start_host"></a> [start\_host](#input\_start\_host) | start host | `number` | `50` | no |
| <a name="input_upload_data"></a> [upload\_data](#input\_upload\_data) | upload the data | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_eck_password"></a> [eck\_password](#output\_eck\_password) | ECK credentials |
| <a name="output_hosts"></a> [hosts](#output\_hosts) | host endpoint |
<!-- END_TF_DOCS -->
