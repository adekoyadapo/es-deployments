
output "host" {
  value = "https://${data.google_container_cluster.main.endpoint}"
}

output "token" {
  value     = data.google_client_config.main.access_token
  sensitive = true
}

output "cluster_ca_certificate" {
  value = base64decode(
    data.google_container_cluster.main.master_auth[0].cluster_ca_certificate,
  )
}