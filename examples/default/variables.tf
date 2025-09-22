variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

variable "service_principal_client_id" {
  type        = string
  default     = null
  description = <<DESCRIPTION
The client ID of the service principal for the ARO cluster.
If not provided, ARO will auto-create a service principal during deployment.
Note: Auto-creation requires the deploying identity to have Azure AD permissions.
DESCRIPTION
  sensitive   = true
}

variable "service_principal_client_secret" {
  type        = string
  default     = null
  description = <<DESCRIPTION
The client secret of the service principal for the ARO cluster.
Required only if service_principal_client_id is provided.
DESCRIPTION
  sensitive   = true
}

variable "service_principal_object_id" {
  type        = string
  default     = null
  description = <<DESCRIPTION
The object ID of the service principal for the ARO cluster.
If provided, a Network Contributor role assignment will be created on the VNet.
If not provided, you must ensure the service principal has the necessary permissions manually.
DESCRIPTION
}
