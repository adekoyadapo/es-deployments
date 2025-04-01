output "es_credentials" {
  description = "Elastic Admin credentials"
  value = {
    username = var.username
    password = random_password.password.result
  }
  sensitive = true
}

output "ingress" {
  description = "Kubernetes Ingress Endpoints"
  value       = { for i, j in data.kubernetes_ingress_v1.ingress : i => { "hosts" = [for k in j.spec.0.rule : k.host] } }
}