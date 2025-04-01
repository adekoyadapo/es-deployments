provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.host
  token                  = data.terraform_remote_state.infra.outputs.token
  cluster_ca_certificate = data.terraform_remote_state.infra.outputs.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.infra.outputs.host
    token                  = data.terraform_remote_state.infra.outputs.token
    cluster_ca_certificate = data.terraform_remote_state.infra.outputs.cluster_ca_certificate
  }
}

provider "kubectl" {
  host                   = data.terraform_remote_state.infra.outputs.host
  token                  = data.terraform_remote_state.infra.outputs.token
  cluster_ca_certificate = data.terraform_remote_state.infra.outputs.cluster_ca_certificate
  load_config_file       = false
}