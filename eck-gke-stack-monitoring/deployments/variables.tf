
variable "dir" {
  type        = string
  description = "ECK dir"
  default     = "quickstart"
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
    set_values = optional(list(object({
      name  = string
      value = string
    })), [])
  }))
  default = {
    "cert-manager" = {
      repository       = "https://charts.jetstack.io"
      chart            = "cert-manager"
      namespace        = "cert-manager"
      create_namespace = true
      version          = "1.15.3"
      set_values = [{
        name  = "crds.enabled"
        value = true
      }]
    }
    "elastic-operator" = {
      repository       = "https://helm.elastic.co"
      chart            = "eck-operator"
      namespace        = "elastic-system"
      create_namespace = true
      version          = "2.16.0"
    }
  }
}

variable "username" {
  description = "default user for elastic"
  default     = "elastic"
  type        = string
}
