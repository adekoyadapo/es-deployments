resource "ec_observability_project" "my_project" {
  count     = var.observability_enabled ? 1 : 0
  name      = var.project_name
  region_id = var.region_id
}

resource "ec_elasticsearch_project" "my_project" {
  count     = var.search_enabled ? 1 : 0
  name      = var.project_name
  region_id = var.region_id
}

resource "ec_security_project" "my_project" {
  count     = var.security_enabled ? 1 : 0
  name      = var.project_name
  region_id = var.region_id
}