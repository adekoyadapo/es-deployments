
variable "source_deployment" {
  type = object({
    name                   = string
    region                 = string
    deployment_template_id = string
    size                   = optional(string, "8g")
    zone_count             = optional(number, 1)
  })
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "version_regex" {
  type    = string
  default = "8.18"
}