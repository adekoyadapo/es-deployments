terraform {
  backend "gcs" {
    bucket = "elastic-customer-eng-tfstate"
    prefix = "terraform/gke-uam-dep"
  }
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
    google = {
      source  = "hashicorp/google"
      version = "6.19.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "6.19.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }

  }
}