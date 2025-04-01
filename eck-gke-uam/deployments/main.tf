locals {
  manifests = {
    for fn in fileset("${path.module}/${var.dir}", "*.yml") :
    fn => templatefile("${path.module}/${var.dir}/${fn}", {
      domain   = "${replace(data.kubernetes_service.lb_ip.status.0.load_balancer.0.ingress.0.ip, ".", "-")}.sslip.io"
      username = var.username
      password = random_password.password.result
    })
    if fn != "stack_monitoring.yml" && fn != "namespace.yml" && fn != "cert.yml" && fn != "stack_monitoring_dev.yml"
  }

  es_deployments = {
    "development"   = "es-ingress-dev"
    "production"    = "es-ingress-prod"
    "observability" = "es-ingress-mon"
  }
}

resource "random_password" "password" {
  length           = 16
  special          = false
  override_special = "!#$%&*()-_=+[]{}<>:?@"
}

resource "helm_release" "charts" {
  provider = helm
  for_each = var.helm_release
  name     = each.key

  repository       = each.value.repository
  chart            = each.value.chart
  namespace        = each.value.namespace
  version          = each.value.version
  create_namespace = true

  values  = fileexists("${path.module}/values/${each.key}.yml") ? [templatefile("${path.module}/values/${each.key}.yml", {})] : null
  timeout = 120

  dynamic "set" {
    for_each = each.value.set_values

    content {
      name  = set.value["name"]
      value = set.value["value"]
    }
  }
}

resource "time_sleep" "lb_ip" {
  depends_on = [helm_release.charts]

  create_duration = "180s"
}

data "kubernetes_service" "lb_ip" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [time_sleep.lb_ip]
}


resource "kubectl_manifest" "eck" {
  for_each = {
    for k, v in local.manifests : k => v
  }

  yaml_body = each.value

  depends_on = [helm_release.charts, kubectl_manifest.certs]
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

  depends_on = [helm_release.charts]
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