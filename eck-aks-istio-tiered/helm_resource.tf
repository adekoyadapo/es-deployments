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
  depends_on = [helm_release.sec]
}