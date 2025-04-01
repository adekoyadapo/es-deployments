data "ec_stack" "latest" {
  version_regex = "8.17"
  region        = var.region
}

data "ec_deployment_templates" "templates" {
  region = var.source_deployment.region
}

resource "ec_deployment" "source" {
  name = var.source_deployment.name

  region                 = data.ec_deployment_templates.templates.region
  version                = data.ec_stack.latest.version
  deployment_template_id = [for i in data.ec_deployment_templates.templates.templates : i.id if length(regexall("general-purpose-faster-warm", i.id)) > 0].0

  elasticsearch = {
    hot = {
      autoscaling = {}
      size        = var.source_deployment.size
      zone_count  = var.source_deployment.zone_count
    }
    kibana = {}

    # Optional observability settings
    observability = {
      deployment_id = "self"
    }

    integrations_server = {}

    tags = {
      "monitoring" = "source"
    }

    ml = {
      zone_count = 1
      autoscaling = {
        autoscale = true
        max_size  = "2g"
        min_size  = "1g"
      }
    }
  }

  kibana = {}
  lifecycle {
    ignore_changes = [integrations_server]
  }
}