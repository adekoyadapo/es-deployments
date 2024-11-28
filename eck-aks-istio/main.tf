locals {
  dir = length(regexall("^8\\.", var.ecs_version)) > 0 ? "manifests" : "manifests_7"
  manifests = {
    for fn in fileset("${path.module}/${local.dir}", "*.yml") :
    fn => templatefile("${path.module}/${local.dir}/${fn}", {
      domain      = var.demo_domain
      ecs_version = var.ecs_version
      sc_name     = azurerm_storage_account.sc.name
      sc_key      = azurerm_storage_account.sc.primary_access_key

    })
  }
  authentication = "${keys(data.kubernetes_resource.eck_password.object.data)[0]}:${base64decode(data.kubernetes_resource.eck_password.object.data.elastic)}"
}

# Generate random resource group name
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = "${var.resource_group_name_prefix}-${random_string.suffix.result}"
}

resource "azurerm_storage_account" "sc" {
  name                      = "snapshot${random_string.suffix.result}" # Must be unique across Azure
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  enable_https_traffic_only = true

  tags = {
    environment = "example"
  }
}

resource "azurerm_storage_container" "sc" {
  name                  = "eck-snapshot-${random_string.suffix.result}"
  storage_account_name  = azurerm_storage_account.sc.name
  container_access_type = "private"
}


resource "azurerm_kubernetes_cluster" "k8s" {
  location            = azurerm_resource_group.rg.location
  name                = "${azurerm_resource_group.rg.name}-aks"
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${azurerm_resource_group.rg.name}-dns"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name       = "agentpool"
    vm_size    = "Standard_D2_v2"
    node_count = var.node_count
  }
  linux_profile {
    admin_username = var.username

    ssh_key {
      key_data = azapi_resource_action.ssh_public_key_gen.output.publicKey
    }
  }
  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }
  lifecycle {
    ignore_changes = [default_node_pool[0].upgrade_settings]
  }
}

resource "kubectl_manifest" "namespace" {
  yaml_body  = <<YAML
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: enabled
  name: eck
YAML
  depends_on = [helm_release.sec]
}

resource "kubernetes_secret" "snapshot" {
  metadata {
    name      = "azure-snapshot-secrets"
    namespace = kubectl_manifest.namespace.name
  }

  data = {
    "azure.client.default.account" = azurerm_storage_account.sc.name
    "azure.client.default.key"     = azurerm_storage_account.sc.primary_access_key
  }

  type = "Opaque"
}

resource "kubectl_manifest" "eck" {
  for_each = { for k, v in local.manifests : k => v }

  yaml_body = each.value

  depends_on = [helm_release.sec, kubectl_manifest.namespace, kubernetes_secret.snapshot]
}

resource "time_sleep" "wait" {
  depends_on = [kubectl_manifest.eck]

  create_duration = "180s"
}

data "kubernetes_resource" "gateway" {
  api_version = "networking.istio.io/v1"
  kind        = "Gateway"

  metadata {
    name      = "gw"
    namespace = kubectl_manifest.namespace.name
  }

  depends_on = [time_sleep.wait]
}

data "kubernetes_resource" "eck_password" {
  api_version = "v1"
  kind        = "Secret"

  metadata {
    name      = "es-es-elastic-user"
    namespace = kubectl_manifest.namespace.name
  }

  depends_on = [time_sleep.wait]
}

data "kubernetes_resource" "gw_ip" {
  api_version = "v1"
  kind        = "Service"

  metadata {
    name      = "istio-ingressgateway"
    namespace = "istio-system"
  }

  depends_on = [time_sleep.wait]
}

data "http" "elasticsearch_request" {
  url = "http://${data.kubernetes_resource.gw_ip.object.status.loadBalancer.ingress[0].ip}"

  request_headers = {
    Host          = "es.${var.demo_domain}"
    authorization = "Basic ${base64encode(local.authentication)}"
  }
  retry {
    attempts     = 5
    max_delay_ms = 5000
    min_delay_ms = 3000
  }
  insecure   = true
  depends_on = [time_sleep.wait]
}
