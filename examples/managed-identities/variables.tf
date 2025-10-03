variable "aro_rp_client_id" {
  type        = string
  default     = "f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875"
  description = "Azure Red Hat OpenShift resource provider service principal client ID"
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
