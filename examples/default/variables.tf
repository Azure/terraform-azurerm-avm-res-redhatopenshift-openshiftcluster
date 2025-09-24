variable "aro_rp_object_id" {
  type        = string
  default     = null
  description = <<DESCRIPTION
Optional object ID for the Azure Red Hat OpenShift resource provider service principal.
Set this when your pipeline lacks permission to query Microsoft Graph for the RP service principal.
If omitted, the example attempts to discover the object ID via the AzureAD provider.
DESCRIPTION
}

variable "cluster_service_principal" {
  type = object({
    client_id     = string
    client_secret = string
    object_id     = string
  })
  default     = null
  description = <<DESCRIPTION
Optional existing service principal values to use for the Azure Red Hat OpenShift cluster.
Provide these when your pipeline cannot create Azure AD applications or service principals.
When omitted, the example will create a new service principal automatically.
DESCRIPTION

  validation {
    condition = var.cluster_service_principal == null || (
        length(trimspace(try(var.cluster_service_principal.client_id, ""))) > 0 &&
        length(trimspace(try(var.cluster_service_principal.client_secret, ""))) > 0 &&
        length(trimspace(try(var.cluster_service_principal.object_id, ""))) > 0
    )
    error_message = "When supplying cluster_service_principal all object properties must be non-empty strings."
  }
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
