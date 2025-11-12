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


output "system_index_api_key" {
  value     = elasticstack_elasticsearch_security_api_key.system_index_access_key
  sensitive = true
}


output "enrich_api_key" {
  value     = elasticstack_elasticsearch_security_api_key.enrich_access_key
  sensitive = true
}