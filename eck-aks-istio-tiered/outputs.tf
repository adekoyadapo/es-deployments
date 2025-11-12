output "kube_config" {
  value       = azurerm_kubernetes_cluster.k8s.kube_config_raw
  sensitive   = true
  description = "Kube config file"
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "hosts" {
  value       = { for i in local.namespace : i => data.kubernetes_resource.gateway[i].object.spec.servers[0].hosts }
  description = "GW hosts"
}

output "eck_password" {
  value = { for i in local.namespace : i => {
    username = keys(data.kubernetes_resource.eck_password[i].object.data)[0]
    password = base64decode(data.kubernetes_resource.eck_password[i].object.data.elastic)
    }
  }
  description = "cluster password"
}

output "lb_ip" {
  value       = data.kubernetes_resource.gw_ip.object.status.loadBalancer.ingress[0].ip
  description = "Endpoint IP"
}

# output "validation_command" {
#   description = "validation cli command"
#   value       = "curl -k -u \"${keys(data.kubernetes_resource.eck_password.object.data)[0]}:${base64decode(data.kubernetes_resource.eck_password.object.data.elastic)}\" http://${data.kubernetes_resource.gw_ip.object.status.loadBalancer.ingress[0].ip} -H \"Host: es.${var.demo_domain}\" "
# }

# output "validation" {
#   value = {
#     server        = data.http.elasticsearch_request.response_headers.Server
#     status_code   = data.http.elasticsearch_request.status_code
#     response_body = data.http.elasticsearch_request.response_body
#   }
#   description = "validation results"
# }

output "gw_ip" {
  value = data.kubernetes_resource.gw_ip.object.status.loadBalancer.ingress[0].ip
}

output "container" {
  value       = azurerm_storage_container.sc.name
  description = "Storage container name"
}