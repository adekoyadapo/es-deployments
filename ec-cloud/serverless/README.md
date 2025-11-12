# Elastic Cloud Serverless Projects

Provision optional observability, search, and security serverless projects in Elastic Cloud using Terraform.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_ec"></a> [ec](#requirement\_ec) | 0.12.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_ec"></a> [ec](#provider\_ec) | 0.12.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [ec_elasticsearch_project.my_project](https://registry.terraform.io/providers/elastic/ec/0.12.2/docs/resources/elasticsearch_project) | resource |
| [ec_observability_project.my_project](https://registry.terraform.io/providers/elastic/ec/0.12.2/docs/resources/observability_project) | resource |
| [ec_security_project.my_project](https://registry.terraform.io/providers/elastic/ec/0.12.2/docs/resources/security_project) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_observability_enabled"></a> [observability\_enabled](#input\_observability\_enabled) | observability enabled | `bool` | `false` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | project name | `string` | `"prj"` | no |
| <a name="input_region_id"></a> [region\_id](#input\_region\_id) | region name | `string` | `"aws-us-east-1"` | no |
| <a name="input_search_enabled"></a> [search\_enabled](#input\_search\_enabled) | elastic search enabled | `bool` | `false` | no |
| <a name="input_security_enabled"></a> [security\_enabled](#input\_security\_enabled) | security enabled | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_observability_credentials"></a> [observability\_credentials](#output\_observability\_credentials) | n/a |
| <a name="output_observability_endpoint"></a> [observability\_endpoint](#output\_observability\_endpoint) | n/a |
| <a name="output_search_credentials"></a> [search\_credentials](#output\_search\_credentials) | n/a |
| <a name="output_search_endpoint"></a> [search\_endpoint](#output\_search\_endpoint) | n/a |
<!-- END_TF_DOCS -->
