data "terraform_remote_state" "infra" {
  backend = "gcs"
  config = {
    bucket = "elastic-customer-eng-tfstate"
    prefix = "terraform/gke-uam"
  }
}
