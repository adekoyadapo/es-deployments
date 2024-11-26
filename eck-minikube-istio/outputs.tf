output "hosts" {
  value       = data.kubernetes_resource.gateway.object.spec.servers[0].hosts
  description = "host endpoint"
}

output "eck_password" {
  value = {
    username = keys(data.kubernetes_resource.eck_password.object.data)[0]
    password = base64decode(data.kubernetes_resource.eck_password.object.data.elastic)
  }
  sensitive   = true
  description = "ECK credentials"
}