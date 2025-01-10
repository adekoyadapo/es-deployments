terraform {
  backend "gcs" {
    bucket = "elastic-customer-eng-tfstate"
    prefix = "terraform/gke-uam"
  }
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.15.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.32.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "5.36.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "5.36.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }

  }
}