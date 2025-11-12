# gke

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_google"></a> [google](#requirement\_google) | 6.19.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | 6.19.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | 2.17.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | 1.19.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.35.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | 1.19.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.35.1 |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
| <a name="provider_time"></a> [time](#provider\_time) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.charts](https://registry.terraform.io/providers/hashicorp/helm/2.17.0/docs/resources/release) | resource |
| [kubectl_manifest.beats](https://registry.terraform.io/providers/gavinbunney/kubectl/1.19.0/docs/resources/manifest) | resource |
| [kubectl_manifest.certs](https://registry.terraform.io/providers/gavinbunney/kubectl/1.19.0/docs/resources/manifest) | resource |
| [kubectl_manifest.eck](https://registry.terraform.io/providers/gavinbunney/kubectl/1.19.0/docs/resources/manifest) | resource |
| [kubectl_manifest.namespace](https://registry.terraform.io/providers/gavinbunney/kubectl/1.19.0/docs/resources/manifest) | resource |
| [random_password.password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [time_sleep.lb_ip](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.wait](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [kubectl_path_documents.beats](https://registry.terraform.io/providers/gavinbunney/kubectl/1.19.0/docs/data-sources/path_documents) | data source |
| [kubectl_path_documents.certs](https://registry.terraform.io/providers/gavinbunney/kubectl/1.19.0/docs/data-sources/path_documents) | data source |
| [kubectl_path_documents.namespace](https://registry.terraform.io/providers/gavinbunney/kubectl/1.19.0/docs/data-sources/path_documents) | data source |
| [kubernetes_ingress_v1.ingress](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/data-sources/ingress_v1) | data source |
| [kubernetes_service.lb_ip](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/data-sources/service) | data source |
| [terraform_remote_state.infra](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_dir"></a> [dir](#input\_dir) | ECK dir | `string` | `"quickstart"` | no |
| <a name="input_helm_release"></a> [helm\_release](#input\_helm\_release) | Helm realease deployment | <pre>map(object({<br/>    repository       = string<br/>    chart            = string<br/>    namespace        = optional(string, "default")<br/>    values           = optional(list(string), [])<br/>    create_namespace = optional(bool, true)<br/>    version          = optional(string)<br/>    wait             = optional(bool, true)<br/>    set_values = optional(list(object({<br/>      name  = string<br/>      value = string<br/>    })), [])<br/>  }))</pre> | <pre>{<br/>  "cert-manager": {<br/>    "chart": "cert-manager",<br/>    "create_namespace": true,<br/>    "namespace": "cert-manager",<br/>    "repository": "https://charts.jetstack.io",<br/>    "set_values": [<br/>      {<br/>        "name": "crds.enabled",<br/>        "value": true<br/>      }<br/>    ],<br/>    "version": "1.15.3"<br/>  },<br/>  "elastic-operator": {<br/>    "chart": "eck-operator",<br/>    "create_namespace": true,<br/>    "namespace": "elastic-system",<br/>    "repository": "https://helm.elastic.co",<br/>    "version": "2.16.0"<br/>  }<br/>}</pre> | no |
| <a name="input_username"></a> [username](#input\_username) | default user for elastic | `string` | `"elastic"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_es_credentials"></a> [es\_credentials](#output\_es\_credentials) | Elastic Admin credentials |
| <a name="output_ingress"></a> [ingress](#output\_ingress) | Kubernetes Ingress Endpoints |
<!-- END_TF_DOCS -->
