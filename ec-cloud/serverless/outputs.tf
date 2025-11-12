output "search_credentials" {
  value = try(ec_elasticsearch_project.my_project[0].credentials, null)
}

output "search_endpoint" {
  value = try(ec_elasticsearch_project.my_project[0].endpoints, null)
}


output "observability_credentials" {
  value = try(ec_observability_project.my_project[0].credentials, null)
}

output "observability_endpoint" {
  value = try(ec_observability_project.my_project[0].endpoints, null)
}
