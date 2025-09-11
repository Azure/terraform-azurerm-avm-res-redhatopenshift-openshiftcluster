output "api_server_ip" {
  description = "The IP address of the API server."
  value       = azurerm_redhat_openshift_cluster.this.api_server_profile[0].ip_address
}

output "api_server_url" {
  description = "The URL of the API server."
  value       = azurerm_redhat_openshift_cluster.this.api_server_profile[0].url
}

output "cluster_resource_group_id" {
  description = "The resource group ID for the cluster-managed resources."
  value       = azurerm_redhat_openshift_cluster.this.cluster_profile[0].resource_group_id
}

# ARO-specific outputs
output "console_url" {
  description = "The URL of the OpenShift web console."
  value       = azurerm_redhat_openshift_cluster.this.console_url
}

output "ingress_ip" {
  description = "The IP address of the ingress."
  value       = azurerm_redhat_openshift_cluster.this.ingress_profile[0].ip_address
}

output "private_endpoints" {
  description = <<DESCRIPTION
  Azure Red Hat OpenShift does not support Azure Private Link endpoints.
  Private connectivity is configured through API server and ingress visibility settings.
  This output is maintained for AVM interface compliance.
  DESCRIPTION
  value       = {}
}

# Module owners should include the full resource via a 'resource' output
# https://azure.github.io/Azure-Verified-Modules/specs/terraform/#id-tffr2---category-outputs---additional-terraform-outputs
output "resource" {
  description = "This is the full output for the Azure Red Hat OpenShift cluster resource."
  value       = azurerm_redhat_openshift_cluster.this
}
