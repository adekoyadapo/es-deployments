data "google_client_config" "main" {
}

data "google_container_cluster" "main" {
  name = google_container_cluster.main.name
}

module "vpc" {
  source  = "terraform-google-modules/network/google//modules/vpc"
  version = "~> 9.1"

  project_id   = var.project
  network_name = var.network_name
}


module "subnets" {
  source  = "terraform-google-modules/network/google//modules/subnets"
  version = "~> 9.1"

  project_id   = var.project
  network_name = module.vpc.network_name

  subnets = [for i, j in var.subnets :
    {
      subnet_name           = i
      subnet_ip             = j.cidr
      subnet_region         = var.region
      description           = "${i} subnet"
      subnet_private_access = true
    }
  ]
  secondary_ranges = var.secondary_ranges
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "google_service_account" "cluster_serviceaccount" {
  account_id   = "gke-sa-${random_string.suffix.result}"
  display_name = "Service Account For Terraform To Make GKE Cluster"
  project      = var.project
}

data "google_iam_role" "iam_role" {
  for_each = toset(var.rolesList)

  name = each.key
}

resource "google_project_iam_member" "sa_iam" {
  for_each = toset(var.rolesList)

  project = var.project
  role    = data.google_iam_role.iam_role[each.key].name
  member  = "serviceAccount:${google_service_account.cluster_serviceaccount.email}"
}

resource "google_container_cluster" "main" {
  name                     = var.cluster_name
  remove_default_node_pool = var.remove_default_node_pool
  location                 = var.region
  project                  = var.project
  network                  = module.vpc.network_name
  subnetwork               = [for i in module.subnets.subnets : i.name][0]
  initial_node_count       = 1

  deletion_protection = false
  ip_allocation_policy {
    cluster_secondary_range_name  = flatten([for i, j in var.secondary_ranges : [for k in j : k.range_name if length(regexall("pods", k.range_name)) > 0]])[0]
    services_secondary_range_name = flatten([for i, j in var.secondary_ranges : [for k in j : k.range_name if length(regexall("services", k.range_name)) > 0]])[0]
  }

  node_config {
    service_account = "default"
    machine_type    = var.machine_type
    disk_size_gb    = 50
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append",
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  cluster_autoscaling {
    enabled             = true
    autoscaling_profile = "BALANCED"
    resource_limits {
      resource_type = "cpu"
      minimum       = 0
      maximum       = 24
    }
    resource_limits {
      resource_type = "memory"
      minimum       = 0
      maximum       = 128
    }
  }
  lifecycle {
    ignore_changes = [node_config]
  }
}



module "gke_auth" {
  source       = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  version      = "23.3.0"
  project_id   = var.project
  cluster_name = google_container_cluster.main.name
  location     = var.region
  depends_on   = [google_container_cluster.main]
}

resource "local_file" "kubeconfig" {
  count = var.create_kubeconfig ? 1 : 0

  file_permission = "0600"
  content         = module.gke_auth.kubeconfig_raw
  filename        = "../${path.cwd}/kubeconfig-${google_container_cluster.main.name}"
  lifecycle {
    ignore_changes = [content]
  }
  provisioner "local-exec" {
    command = "rm -rf ${self.filename}"
    when    = destroy
  }
}