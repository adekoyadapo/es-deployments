# eck-aks-istio

## Sample deployments with Istio - non-ssl and Elastic Search ingress with Istio ingressgateway

## Additional

- Integration of snapshot with azure storage
- Manifest for deployments in both 7.x and 8.x cluster versions

Example setup

```bash
# Create snapshot
curl -X PUT -k -u "elastic:your_password" \
  "http://<ELASTICSEARCH_IP>/_snapshot/azure" \
  -H "Host: es.<DEMO_DOMAIN>" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "azure",
    "settings": {
      "location": "/",
      "client": "default",
      "container": "<container_name>"
    }
  }'
```

```bash
# verfiy snapshot
curl -X POST -k -u "elastic:your_password" \
  "http://<ELASTICSEARCH_IP>/_snapshot/azure/_verify" \
  -H "Host: es.<DEMO_DOMAIN>" \
  -H "Content-Type: application/json"
```

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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) | ~>1.5 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | 3.111.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.10.1 |
| <a name="requirement_http"></a> [http](#requirement\_http) | 3.4.5 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.14 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.22.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~>3.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | 0.9.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azapi"></a> [azapi](#provider\_azapi) | 1.15.0 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 3.111.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.10.1 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.4.5 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | 1.16.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.22.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.6.3 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.9.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azapi_resource.ssh_public_key](https://registry.terraform.io/providers/azure/azapi/latest/docs/resources/resource) | resource |
| [azapi_resource_action.ssh_public_key_gen](https://registry.terraform.io/providers/azure/azapi/latest/docs/resources/resource_action) | resource |
| [azurerm_kubernetes_cluster.k8s](https://registry.terraform.io/providers/hashicorp/azurerm/3.111.0/docs/resources/kubernetes_cluster) | resource |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/3.111.0/docs/resources/resource_group) | resource |
| [azurerm_storage_account.sc](https://registry.terraform.io/providers/hashicorp/azurerm/3.111.0/docs/resources/storage_account) | resource |
| [azurerm_storage_container.sc](https://registry.terraform.io/providers/hashicorp/azurerm/3.111.0/docs/resources/storage_container) | resource |
| [helm_release.gateway](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.main](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.sec](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.eck](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.namespace](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_secret.snapshot](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [time_sleep.wait](https://registry.terraform.io/providers/hashicorp/time/0.9.1/docs/resources/sleep) | resource |
| [http_http.elasticsearch_request](https://registry.terraform.io/providers/hashicorp/http/3.4.5/docs/data-sources/http) | data source |
| [kubernetes_resource.eck_password](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/resource) | data source |
| [kubernetes_resource.gateway](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/resource) | data source |
| [kubernetes_resource.gw_ip](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/resource) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_demo_domain"></a> [demo\_domain](#input\_demo\_domain) | demo domain name | `string` | `"eck.demo"` | no |
| <a name="input_dir"></a> [dir](#input\_dir) | dir holding esk manifests | `string` | `"manifests"` | no |
| <a name="input_ecs_version"></a> [ecs\_version](#input\_ecs\_version) | Elastic Search Version | `string` | `"8.16.1"` | no |
| <a name="input_helm_release"></a> [helm\_release](#input\_helm\_release) | Helm realease deployment | <pre>map(object({<br/>    repository       = string<br/>    chart            = string<br/>    namespace        = optional(string, "default")<br/>    values           = optional(list(string), [])<br/>    create_namespace = optional(bool, true)<br/>    version          = optional(string)<br/>    wait             = optional(bool, true)<br/>    is_main          = optional(bool, true)<br/>    set_values = optional(list(object({<br/>      name  = string<br/>      value = string<br/>    })), [])<br/>  }))</pre> | <pre>{<br/>  "elastic-operator": {<br/>    "chart": "eck-operator",<br/>    "create_namespace": true,<br/>    "namespace": "elastic-system",<br/>    "repository": "https://helm.elastic.co",<br/>    "version": "2.14.0"<br/>  }<br/>}</pre> | no |
| <a name="input_msi_id"></a> [msi\_id](#input\_msi\_id) | The Managed Service Identity ID. Set this value if you're running this example using Managed Identity as the authentication method. | `string` | `null` | no |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | The initial quantity of nodes for the node pool. | `number` | `3` | no |
| <a name="input_resource_group_location"></a> [resource\_group\_location](#input\_resource\_group\_location) | Location of the resource group. | `string` | `"eastus2"` | no |
| <a name="input_resource_group_name_prefix"></a> [resource\_group\_name\_prefix](#input\_resource\_group\_name\_prefix) | Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription. | `string` | `"eck-rg"` | no |
| <a name="input_username"></a> [username](#input\_username) | The admin username for the new cluster. | `string` | `"azureadmin"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_container"></a> [container](#output\_container) | Storage container name |
| <a name="output_eck_password"></a> [eck\_password](#output\_eck\_password) | cluster password |
| <a name="output_hosts"></a> [hosts](#output\_hosts) | GW hosts |
| <a name="output_key_data"></a> [key\_data](#output\_key\_data) | n/a |
| <a name="output_kube_config"></a> [kube\_config](#output\_kube\_config) | Kube config file |
| <a name="output_lb_ip"></a> [lb\_ip](#output\_lb\_ip) | Endpoint IP |
| <a name="output_validation"></a> [validation](#output\_validation) | validation results |
| <a name="output_validation_command"></a> [validation\_command](#output\_validation\_command) | validation cli command |
<!-- END_TF_DOCS -->