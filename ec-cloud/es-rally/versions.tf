terraform {
  required_providers {
    ec = {
      source  = "elastic/ec"
      version = "0.11.0"
    }
    elasticstack = {
      source  = "elastic/elasticstack"
      version = "~>0.9"
    }
  }
}

provider "ec" {
}

provider "elasticstack" {
  alias = "leader"
  elasticsearch {
    username  = "elastic"
    password  = ec_deployment.source.elasticsearch_password
    endpoints = [ec_deployment.source.elasticsearch.https_endpoint]
  }
}

provider "elasticstack" {
  alias = "follower"
  elasticsearch {
    username  = "elastic"
    password  = ec_deployment.ccs.elasticsearch_password
    endpoints = [ec_deployment.ccs.elasticsearch.https_endpoint]
  }
}