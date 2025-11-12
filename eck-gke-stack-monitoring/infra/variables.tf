variable "project" {
  type        = string
  description = "Project Name"
}

variable "region" {
  type        = string
  description = "Resource Region"
}

variable "cluster_name" {
  type        = string
  default     = "ecs-gke"
  description = "Cluster Name"
}

variable "labels" {
  type        = map(string)
  description = "Resource Label"
  default = {
    "created_by" = "terraform"
    "managed_by" = "ade"
  }
}
variable "network_name" {
  type        = string
  default     = "gke-eck"
  description = "Name of the GKE VPC network"
}

variable "subnets" {
  description = "Subnets for hosting GKE resources"
  type = map(object({
    cidr = string
  }))
  default = {
    "nodes" = {
      cidr = "10.0.10.0/24"
    }
  }
}

variable "secondary_ranges" {
  description = "Subnets for hosting GKE services"
  type = map(list(object({
    range_name    = string
    ip_cidr_range = string
  })))
  default = {
    "gke-nodes" = [{
      range_name    = "gke-services"
      ip_cidr_range = "10.0.11.0/24"
    }]
  }
}

variable "rolesList" {
  type        = list(string)
  description = "List of roles required by the GKE service account"

  default = [
    "roles/storage.objectViewer",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/compute.osLogin"
  ]
}

variable "service_account_roles_supplemental" {
  type        = list(string)
  description = "Supplementary list of roles for bastion host"
  default = [
    "roles/container.developer"
  ]
}

variable "remove_default_node_pool" {
  type        = bool
  default     = true
  description = "Remove the default node pool created by GKE"
}

variable "cluster_autoscaling" {
  type = object({
    enabled                     = bool
    autoscaling_profile         = string
    min_cpu_cores               = number
    max_cpu_cores               = number
    min_memory_gb               = number
    max_memory_gb               = number
    gpu_resources               = list(object({ resource_type = string, minimum = number, maximum = number }))
    auto_repair                 = bool
    auto_upgrade                = bool
    disk_size                   = optional(number)
    disk_type                   = optional(string)
    image_type                  = optional(string)
    strategy                    = optional(string)
    max_surge                   = optional(number)
    max_unavailable             = optional(number)
    node_pool_soak_duration     = optional(string)
    batch_soak_duration         = optional(string)
    batch_percentage            = optional(number)
    batch_node_count            = optional(number)
    enable_secure_boot          = optional(bool, false)
    enable_integrity_monitoring = optional(bool, true)
  })
  default = {
    enabled                     = true
    autoscaling_profile         = "BALANCED"
    max_cpu_cores               = 64
    min_cpu_cores               = 0
    max_memory_gb               = 256
    min_memory_gb               = 0
    gpu_resources               = []
    auto_repair                 = true
    auto_upgrade                = true
    disk_size                   = 50
    disk_type                   = "pd-standard"
    image_type                  = "COS_CONTAINERD"
    enable_secure_boot          = false
    enable_integrity_monitoring = true
  }
  description = "Cluster autoscaling configuration. See [more details](https://cloud.google.com/kubernetes-engine/docs/reference/rest/v1beta1/projects.locations.clusters#clusterautoscaling)"
}

variable "create_kubeconfig" {
  default     = true
  description = "Enable creation of local kubeconfig file"
  type        = bool
}

variable "machine_type" {
  type        = string
  default     = "e2-medium"
  description = "Default machine type for default node-pool"
}

variable "email" {
  type        = string
  default     = "elastic"
  description = "Please, enter your email (elastic email) or a user"
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