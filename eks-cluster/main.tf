# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "aws" {
  region = var.region
}

# Filter out local zones, which are not currently supported 
# with managed node groups
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  cluster_name = "eck-eks-${random_string.suffix.result}"
  azs          = slice(data.aws_availability_zones.available.names, 0, 3)
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.17.0"

  name = "eck-vpc"

  cidr = var.vpc_cidr
  azs  = local.azs

  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 52)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
  tags = var.tags
}


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.33.1"

  cluster_name    = local.cluster_name
  cluster_version = "1.31"

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  tags = var.tags
}



# module "eks" {
#   source  = "terraform-aws-modules/eks/aws"
#   version = "20.33.1"

#   cluster_name    = local.cluster_name
#   cluster_version = "1.30"

#   cluster_endpoint_public_access           = true
#   enable_cluster_creator_admin_permissions = true

#   vpc_id     = module.vpc.vpc_id
#   subnet_ids = module.vpc.private_subnets

#   eks_managed_node_group_defaults = {
#     disk_size = 100
#   }


#   eks_managed_node_groups = {
#     one = {
#       name = "node-group-1"

#       instance_types = ["m5.xlarge"]

#       min_size     = 1
#       max_size     = 2
#       desired_size = 2
#     }

#     two = {
#       name = "node-group-2"

#       instance_types = ["m5.xlarge"]

#       min_size     = 1
#       max_size     = 3
#       desired_size = 2
#     }
#   }
# }