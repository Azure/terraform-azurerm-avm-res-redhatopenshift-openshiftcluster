variable "service_principal_client_id" {
  type        = string
  description = <<DESCRIPTION
The client ID of the service principal for the ARO cluster.
This service principal must have appropriate permissions to create and manage the cluster.
DESCRIPTION
  sensitive = true
}

variable "service_principal_client_secret" {
  type        = string
  description = <<DESCRIPTION
The client secret of the service principal for the ARO cluster.
DESCRIPTION
  sensitive = true
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

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}
