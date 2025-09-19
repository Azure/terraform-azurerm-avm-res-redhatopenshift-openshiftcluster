variable "assign_aro_rp_permissions" {
  type        = bool
  default     = false
  description = <<DESCRIPTION
Whether to assign Network Contributor permissions to the Azure Red Hat OpenShift Resource Provider.
This requires the ARO RP to be registered in the tenant. Set to false for CI/CD environments
where the ARO RP may not be available.
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
