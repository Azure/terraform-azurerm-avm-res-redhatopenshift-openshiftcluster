variable "aro_rp_object_id" {
  type        = string
  default     = null
  description = <<DESCRIPTION
Optional object ID for the Azure Red Hat OpenShift resource provider service principal.
Set this when your pipeline lacks permission to query Microsoft Graph for the RP service principal.
If omitted, the example attempts to discover the object ID via the AzureAD provider.
DESCRIPTION
}

variable "location" {
  type        = string
  default     = "centralus"
  description = <<DESCRIPTION
Azure region to deploy the example resources into. Choose a region with sufficient Azure Red Hat OpenShift capacity.
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
