terraform {
  required_providers {
    ec = {
      source = "elastic/ec"
      version = "0.12.2"
    }
  }
}

provider "ec" {
  # Configuration options
}