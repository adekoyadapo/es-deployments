# ec-cloud

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_ec"></a> [ec](#requirement\_ec) | 0.12.2 |
| <a name="requirement_elasticstack"></a> [elasticstack](#requirement\_elasticstack) | ~>0.9 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_ec"></a> [ec](#provider\_ec) | 0.12.2 |
| <a name="provider_elasticstack"></a> [elasticstack](#provider\_elasticstack) | ~>0.9 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [ec_deployment.source](https://registry.terraform.io/providers/elastic/ec/0.12.2/docs/resources/deployment) | resource |
| [elasticstack_elasticsearch_security_api_key.api_key](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/elasticsearch_security_api_key) | resource |
| [ec_deployment_templates.templates](https://registry.terraform.io/providers/elastic/ec/0.12.2/docs/data-sources/deployment_templates) | data source |
| [ec_stack.latest](https://registry.terraform.io/providers/elastic/ec/0.12.2/docs/data-sources/stack) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_region"></a> [region](#input\_region) | n/a | `string` | `"us-east-1"` | no |
| <a name="input_source_deployment"></a> [source\_deployment](#input\_source\_deployment) | n/a | <pre>object({<br/>    name                   = string<br/>    region                 = string<br/>    deployment_template_id = string<br/>    size                   = optional(string, "8g")<br/>    zone_count             = optional(number, 1)<br/>  })</pre> | n/a | yes |
| <a name="input_version_regex"></a> [version\_regex](#input\_version\_regex) | n/a | `string` | `"8.18"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_key"></a> [api\_key](#output\_api\_key) | n/a |
| <a name="output_cloud_id"></a> [cloud\_id](#output\_cloud\_id) | n/a |
| <a name="output_credentials"></a> [credentials](#output\_credentials) | n/a |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | n/a |
<!-- END_TF_DOCS -->
