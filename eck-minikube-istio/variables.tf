variable "cluster_name" {
  type        = string
  description = "cluster_name"
  default     = "demo"
}

variable "cluster_image" {
  type        = string
  description = "Cluster iamge"
  default     = "rancher/k3s:v1.30.4-k3s1"
}

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
    is_main          = optional(bool, true)
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
      version          = "2.14.0"
    }
  }
}


variable "upload_data" {
  description = "upload the data"
  default     = true
  type        = bool
}

variable "start_host" {
  description = "start host"
  default     = 50
  type        = number
}