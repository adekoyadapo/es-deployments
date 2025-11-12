provider "google" {
  project = var.project
  region  = var.region
}

provider "kubernetes" {
  host  = "https://${data.google_container_cluster.main.endpoint}"
  token = data.google_client_config.main.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.main.master_auth[0].cluster_ca_certificate,
  )
}

provider "helm" {
  kubernetes {
    host  = "https://${data.google_container_cluster.main.endpoint}"
    token = data.google_client_config.main.access_token
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.main.master_auth[0].cluster_ca_certificate,
    )
  }
}

provider "kubectl" {
  host  = "https://${data.google_container_cluster.main.endpoint}"
  token = data.google_client_config.main.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.main.master_auth[0].cluster_ca_certificate,
  )
  load_config_file = false
}