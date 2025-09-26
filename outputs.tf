output "api_server_url" {
  description = "Azure Red Hat OpenShift API server URL."
  value       = local.cluster_api_server_url
}

output "console_url" {
  description = "Azure Red Hat OpenShift console URL."
  value       = local.cluster_console_url
}

output "domain" {
  description = "DNS domain suffix for the cluster."
  value       = local.cluster_domain
}

output "id" {
  description = "Resource ID of the ARO cluster."
  value       = azapi_resource.this.id
}

output "location" {
  value = var.location
}

output "name" {
  value = var.name
}

output "resource_group_name" {
  value = var.resource_group_name
}
