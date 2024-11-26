output "kube_config" {
  value     = azurerm_kubernetes_cluster.k8s.kube_config_raw
  sensitive = true
}

output "hosts" {
  value = data.kubernetes_resource.gateway.object.spec.servers[0].hosts
}

output "eck_password" {
  value = {
    username = keys(data.kubernetes_resource.eck_password.object.data)[0]
    password = base64decode(data.kubernetes_resource.eck_password.object.data.elastic)
  }
}

output "lb_ip" {
  value = data.kubernetes_resource.gw_ip.object.status.loadBalancer.ingress[0].ip
}

output "validation_command" {
  value = "curl -k -u \"${keys(data.kubernetes_resource.eck_password.object.data)[0]}:${base64decode(data.kubernetes_resource.eck_password.object.data.elastic)}\" http://${data.kubernetes_resource.gw_ip.object.status.loadBalancer.ingress[0].ip} -H \"Host: es.${var.demo_domain}\" "
}

output "validation" {
  value = {
    server        = data.http.elasticsearch_request.response_headers.Server
    status_code   = data.http.elasticsearch_request.status_code
    response_body = data.http.elasticsearch_request.response_body
  }
}