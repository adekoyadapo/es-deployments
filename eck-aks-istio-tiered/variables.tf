
variable "resource_group_location" {
  type        = string
  default     = "eastus2"
  description = "Location of the resource group."
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "eck-rg"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "node_count" {
  type        = number
  description = "The initial quantity of nodes for the node pool."
  default     = 3
}

variable "msi_id" {
  type        = string
  description = "The Managed Service Identity ID. Set this value if you're running this example using Managed Identity as the authentication method."
  default     = null
}

variable "username" {
  type        = string
  description = "The admin username for the new cluster."
  default     = "azureadmin"
}

variable "helm_release" {
  description = "Helm realease deployment"
  type = map(object({
    repository       = string
    chart            = string
    namespace        = optional(string, "default")
    values           = optional(list(string), [])
    create_namespace = optional(bool, true)
    version          = optional(string)
    wait             = optional(bool, true)
    is_main          = optional(bool, true)
    set_values = optional(list(object({
      name  = string
      value = string
    })), [])
  }))
  default = {
    "elastic-operator" = {
      repository       = "https://helm.elastic.co"
      chart            = "eck-operator"
      namespace        = "elastic-system"
      create_namespace = true
      version          = "2.14.0"
    }
  }
}

variable "demo_domain" {
  type        = string
  default     = "eck.demo"
  description = "demo domain name"
}

variable "dir" {
  type        = string
  default     = "manifests"
  description = "dir holding esk manifests"
}

variable "ecs_version" {
  type        = string
  default     = "8.16.1"
  description = "Elastic Search Version"
}