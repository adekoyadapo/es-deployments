# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "vpc cider"
  type        = string
  default     = "10.1.0.0/16"
}

variable "tags" {
  description = "tags"
  type        = map(string)
  default = {
    "owner"       = "eck-uam"
    "environment" = "test"
  }
}