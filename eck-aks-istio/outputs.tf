output "kube_config" {
  value     = azurerm_kubernetes_cluster.k8s.kube_config_raw
  sensitive = true
  description = "Kube config file"
}

output "hosts" {
  value = data.kubernetes_resource.gateway.object.spec.servers[0].hosts
  description = "GW hosts"
}

output "eck_password" {
  value = {
    username = keys(data.kubernetes_resource.eck_password.object.data)[0]
    password = base64decode(data.kubernetes_resource.eck_password.object.data.elastic)
  }
  description = "cluster password"
}

output "lb_ip" {
  value = data.kubernetes_resource.gw_ip.object.status.loadBalancer.ingress[0].ip
  description = "Endpoint IP"
}

output "validation_command" {
  description = "validation cli command"
  value = "curl -k -u \"${keys(data.kubernetes_resource.eck_password.object.data)[0]}:${base64decode(data.kubernetes_resource.eck_password.object.data.elastic)}\" http://${data.kubernetes_resource.gw_ip.object.status.loadBalancer.ingress[0].ip} -H \"Host: es.${var.demo_domain}\" "
}

output "validation" {
  value = {
    server        = data.http.elasticsearch_request.response_headers.Server
    status_code   = data.http.elasticsearch_request.status_code
    response_body = data.http.elasticsearch_request.response_body
  }
  description = "validation results"
}

output "container" {
  value = azurerm_storage_container.sc.name
  description = "Storage container name"
}