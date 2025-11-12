variable "project_name" {
  description = "project name"
  type        = string
  default     = "prj"
}

variable "region_id" {
  description = "region name"
  type        = string
  default     = "aws-us-east-1"
}

variable "observability_enabled" {
  description = "observability enabled"
  type        = bool
  default     = false
}

variable "search_enabled" {
  description = "elastic search enabled"
  type        = bool
  default     = false
}

variable "security_enabled" {
  description = "security enabled"
  type        = bool
  default     = false
}