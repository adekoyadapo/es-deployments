locals {
  manifests = {
    for fn in fileset("${path.module}/${var.dir}", "*.yml") :
    fn => templatefile("${path.module}/${var.dir}/${fn}", {
      domain   = data.external.getip.result.sslip_io
      username = var.username
      password = random_password.password.result
    })
    if fn != "stack_monitoring.yml" && fn != "namespace.yml" && fn != "cert.yml" && fn != "stack_monitoring_dev.yml"
  }
  es_deployments = {
    "production"    = "es-ingress-prod"
    "observability" = "es-ingress-mon"
  }
  ingress_hosts = { for i, j in data.kubernetes_ingress_v1.ingress : i => { "hosts" = [for k in j.spec.0.rule : k.host] } }
}


resource "random_password" "password" {
  length           = 16
  special          = false
  override_special = "!#$%&*()-_=+[]{}<>:?@"
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
    "ingress",
    "storage-provisioner",
    "default-storageclass",
    "metrics-server",
    "registry",
    "registry-aliases"
  ]
}

data "external" "getip" {
  program    = ["bash", "${path.module}/getip.sh", var.cluster_name]
  depends_on = [minikube_cluster.cluster]
}

resource "helm_release" "charts" {
  for_each = var.helm_release
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


resource "kubectl_manifest" "eck" {
  for_each = {
    for k, v in local.manifests : k => v
  }

  yaml_body = each.value

  depends_on = [helm_release.charts, kubectl_manifest.certs, data.external.getip]
}

data "kubectl_path_documents" "namespace" {
  count            = length(regexall("stack", var.dir)) > 0 ? 1 : 0
  pattern          = "${path.module}/${var.dir}/namespace.yml"
  disable_template = true
}

data "kubectl_path_documents" "certs" {
  count            = length(regexall("uam|stack", var.dir)) > 0 ? 1 : 0
  pattern          = "${path.module}/${var.dir}/cert*.yml"
  disable_template = true
}

data "kubectl_path_documents" "beats" {
  count            = length(regexall("uam|stack", var.dir)) > 0 ? 1 : 0
  pattern          = "${path.module}/${var.dir}/stack*.yml"
  disable_template = true
}

resource "kubectl_manifest" "namespace" {
  for_each = length(regexall("uam|stack", var.dir)) > 0 ? toset(data.kubectl_path_documents.namespace[0].documents) : []

  yaml_body = each.value

  depends_on = [helm_release.charts, data.external.getip]
}

resource "kubectl_manifest" "certs" {
  for_each = toset(data.kubectl_path_documents.certs[0].documents)

  yaml_body = each.value

  depends_on = [helm_release.charts, kubectl_manifest.namespace]
}

resource "kubectl_manifest" "beats" {
  for_each = toset(data.kubectl_path_documents.beats[0].documents)

  yaml_body = each.value

  depends_on = [helm_release.charts, kubectl_manifest.certs, kubectl_manifest.eck]
}

resource "time_sleep" "wait" {
  depends_on = [kubectl_manifest.eck]

  create_duration = "180s"
}

data "kubernetes_ingress_v1" "ingress" {
  depends_on = [time_sleep.wait]
  for_each   = local.es_deployments
  metadata {
    name      = each.value
    namespace = each.key
  }
}