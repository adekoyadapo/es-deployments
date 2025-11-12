provider "elasticstack" {
  alias = "mon"
  elasticsearch {
    username = var.username
    password = random_password.password.result
    endpoints = [
      for h in local.ingress_hosts["observability"].hosts :
      "https://${h}" if can(regex("^es-", h))
    ]
    insecure = true
  }
}

provider "elasticstack" {
  alias = "prod"
  elasticsearch {
    username = var.username
    password = random_password.password.result
    endpoints = [
      for h in local.ingress_hosts["production"].hosts :
      "https://${h}" if can(regex("^es-", h))
    ]
    insecure = true
  }
}

resource "elasticstack_elasticsearch_security_api_key" "system_index_access_key" {
  provider = elasticstack.prod
  name     = "system_index_access_key"

  role_descriptors = jsonencode({
    system_index_access = {
      cluster = ["all"],
      indices = [
        {
          names                    = [".kibana_analytics*", "kibana_objects*"],
          privileges               = ["all"],
          allow_restricted_indices = true
        }
      ]
    }
  })
  depends_on = [time_sleep.wait]
}


resource "elasticstack_elasticsearch_security_api_key" "enrich_access_key" {
  provider = elasticstack.mon
  name     = "enrich_access_key"

  role_descriptors = jsonencode({
    system_index_access = {
      cluster = ["all"],
      indices = [
        {
          names                    = ["kibana_objects-*"],
          privileges               = ["all"],
          allow_restricted_indices = true
        }
      ]
    }
  })
  depends_on = [time_sleep.wait]
}
