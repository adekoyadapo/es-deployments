
locals {
  manifests = {
    for fn in fileset("${path.module}/${var.dir}", "*.yml") :
    fn => templatefile("${path.module}/${var.dir}/${fn}", {
      domain   = format("%s.%s", replace("${local.start_ip}", ".", "-"), "sslip.io")
      start_ip = local.start_ip
      end_ip   = local.end_ip
    })
  }

  end_host = var.start_host + 100
  start_ip = cidrhost(data.external.getip.result.private_network, var.start_host)
  end_ip   = cidrhost(data.external.getip.result.private_network, local.end_host)

  create_metallb = contains([for i in var.helm_release : i], "metallb")
}

resource "minikube_cluster" "cluster" {
  vm                = true
  driver            = "qemu"
  cluster_name      = var.cluster_name
  nodes             = 2
  cni               = "bridge"
  network           = "socket_vmnet"
  container_runtime = "cri-o"
  delete_on_failure = true
  memory            = "24gb"
  cpus              = 12
  addons = [
    "storage-provisioner",
    "default-storageclass",
    "metrics-server",
    "metallb"
  ]
}

data "external" "getip" {
  program    = ["bash", "${path.module}/getip.sh", var.cluster_name]
  depends_on = [minikube_cluster.cluster]
}

resource "helm_release" "main" {
  for_each = { for i, j in var.helm_release : i => j if j.is_main == true }
  name     = each.key

  repository       = each.value.repository
  chart            = each.value.chart
  namespace        = each.value.namespace
  version          = each.value.version
  create_namespace = true

  values  = fileexists("${path.module}/values/${each.key}.yml") ? [templatefile("${path.module}/values/${each.key}.yml", )] : null
  timeout = 120

  dynamic "set" {
    for_each = each.value.set_values

    content {
      name  = set.value["name"]
      value = set.value["value"]
    }
  }
}

resource "helm_release" "sec" {
  for_each = { for i, j in var.helm_release : i => j if j.is_main == false && i != "istio-ingressgateway" }
  name     = each.key

  repository       = each.value.repository
  chart            = each.value.chart
  namespace        = each.value.namespace
  version          = each.value.version
  create_namespace = true

  values  = fileexists("${path.module}/values/${each.key}.yml") ? [templatefile("${path.module}/values/${each.key}.yml", )] : null
  timeout = 120

  dynamic "set" {
    for_each = each.value.set_values

    content {
      name  = set.value["name"]
      value = set.value["value"]
    }
  }
  depends_on = [helm_release.main]
}

resource "helm_release" "gateway" {
  for_each = { for i, j in var.helm_release : i => j if i == "istio-ingressgateway" }
  name     = each.key

  repository       = each.value.repository
  chart            = each.value.chart
  namespace        = each.value.namespace
  version          = each.value.version
  create_namespace = true

  values  = fileexists("${path.module}/values/${each.key}.yml") ? [templatefile("${path.module}/values/${each.key}.yml", )] : null
  timeout = 120

  dynamic "set" {
    for_each = each.value.set_values

    content {
      name  = set.value["name"]
      value = set.value["value"]
    }
  }
  depends_on = [helm_release.sec, kubectl_manifest.eck]
}

resource "kubectl_manifest" "namespace" {
  yaml_body = <<YAML
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: enabled
  name: eck
YAML
}

resource "kubectl_manifest" "eck" {
  for_each = {
    for k, v in local.manifests : k => v if k != "metallb-ip.yml"
  }

  yaml_body = each.value

  depends_on = [helm_release.sec, kubectl_manifest.metallb, kubectl_manifest.namespace]
}

resource "kubectl_manifest" "metallb" {
  for_each = {
    for k, v in local.manifests : k => v if k == "metallb-ip.yml"
  }

  yaml_body = each.value

  depends_on = [helm_release.main]
}

resource "time_sleep" "wait" {
  depends_on = [kubectl_manifest.eck]

  create_duration = "90s"
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