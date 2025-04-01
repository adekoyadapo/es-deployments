data "ec_stack" "latest" {
  version_regex = "latest"
  region        = "us-east-1"
}

resource "ec_deployment" "source" {
  name = var.source_deployment.name

  region                 = var.source_deployment.region
  version                = data.ec_stack.latest.version
  deployment_template_id = var.source_deployment.deployment_template_id

  elasticsearch = {
    hot = {
      autoscaling = {}
      size        = var.source_deployment.size
      zone_count  = var.source_deployment.zone_count
    }
  }

  kibana = {}
}

resource "ec_deployment" "ccs" {
  name = var.destination_deployment.name

  region                 = var.destination_deployment.region
  version                = data.ec_stack.latest.version
  deployment_template_id = var.destination_deployment.deployment_template_id

  elasticsearch = {
    hot = {
      autoscaling = {}
      size        = var.destination_deployment.size
      zone_count  = var.destination_deployment.zone_count
    }
    remote_cluster = [{
      deployment_id = ec_deployment.source.id
      alias         = ec_deployment.source.name
      ref_id        = ec_deployment.source.elasticsearch.ref_id
    }]
  }

  kibana = {
    zone_count = 1
  }
}