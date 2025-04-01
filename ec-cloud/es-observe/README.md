# ec-cloud

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_ec"></a> [ec](#requirement\_ec) | 0.11.0 |
| <a name="requirement_elasticstack"></a> [elasticstack](#requirement\_elasticstack) | ~>0.9 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_ec"></a> [ec](#provider\_ec) | 0.11.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [ec_deployment.ccs](https://registry.terraform.io/providers/elastic/ec/0.11.0/docs/resources/deployment) | resource |
| [ec_deployment.source](https://registry.terraform.io/providers/elastic/ec/0.11.0/docs/resources/deployment) | resource |
| [ec_stack.latest](https://registry.terraform.io/providers/elastic/ec/0.11.0/docs/data-sources/stack) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_destination_deployment"></a> [destination\_deployment](#input\_destination\_deployment) | n/a | <pre>object({<br/>    name                   = string<br/>    region                 = string<br/>    deployment_template_id = string<br/>    size                   = optional(string, "16g")<br/>    zone_count             = optional(number, 2)<br/>  })</pre> | n/a | yes |
| <a name="input_source_deployment"></a> [source\_deployment](#input\_source\_deployment) | n/a | <pre>object({<br/>    name                   = string<br/>    region                 = string<br/>    deployment_template_id = string<br/>    size                   = optional(string, "16g")<br/>    zone_count             = optional(number, 2)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_id"></a> [cloud\_id](#output\_cloud\_id) | n/a |
| <a name="output_credentials"></a> [credentials](#output\_credentials) | n/a |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | n/a |
| <a name="output_env"></a> [env](#output\_env) | n/a |
<!-- END_TF_DOCS -->
