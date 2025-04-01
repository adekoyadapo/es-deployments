
variable "source_deployment" {
  type = object({
    name                   = string
    region                 = string
    deployment_template_id = string
    size                   = optional(string, "16g")
    zone_count             = optional(number, 2)
  })
}

variable "destination_deployment" {
  type = object({
    name                   = string
    region                 = string
    deployment_template_id = string
    size                   = optional(string, "16g")
    zone_count             = optional(number, 2)
  })
}