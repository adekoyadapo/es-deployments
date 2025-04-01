resource "ec_observability_project" "my_project" {
  name      = var.project_name
  region_id = var.region_id
}