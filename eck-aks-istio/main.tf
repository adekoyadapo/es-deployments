locals {
  manifests = {
    for fn in fileset("${path.module}/${var.dir}", "*.yml") :
    fn => templatefile("${path.module}/${var.dir}/${fn}", {
      domain = var.demo_domain
    })
  }
  authentication = "${keys(data.kubernetes_resource.eck_password.object.data)[0]}:${base64decode(data.kubernetes_resource.eck_password.object.data.elastic)}"
}

# Generate random resource group name
resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

resource "random_pet" "azurerm_kubernetes_cluster_name" {
  prefix = "cluster"
}

resource "random_pet" "azurerm_kubernetes_cluster_dns_prefix" {
  prefix = "dns"
}

resource "azurerm_kubernetes_cluster" "k8s" {
  location            = azurerm_resource_group.rg.location
  name                = random_pet.azurerm_kubernetes_cluster_name.id
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = random_pet.azurerm_kubernetes_cluster_dns_prefix.id

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

resource "kubectl_manifest" "eck" {
  for_each = { for k, v in local.manifests : k => v }

  yaml_body = each.value

  depends_on = [helm_release.sec, kubectl_manifest.namespace]
}

resource "time_sleep" "wait" {
  depends_on = [kubectl_manifest.eck]

  create_duration = "120s"
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
  insecure   = true
  depends_on = [time_sleep.wait]
}