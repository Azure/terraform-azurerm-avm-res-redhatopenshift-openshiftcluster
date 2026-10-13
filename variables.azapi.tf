variable "ignore_body_changes" {
  type = object({
    redhatopenshift_open_shift_clusters = optional(list(string), [])
    authorization_role_assignments      = optional(list(string), [])
    authorization_locks                 = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Body-relative paths to ignore for each AzAPI resource. Paths use dot notation. Changes take effect only after apply. Ignored configuration is not sent to Azure until the path is removed. Non-empty lists require Terraform 1.11 or later.

- `redhatopenshift_open_shift_clusters` - Paths ignored on the OpenShift cluster.
- `authorization_role_assignments` - Paths ignored on private endpoint role assignments.
- `authorization_locks` - Paths ignored on private endpoint locks.
DESCRIPTION
  nullable    = false
}

variable "resource_types" {
  type = object({
    redhatopenshift_open_shift_clusters = optional(string, "Microsoft.RedHatOpenShift/openShiftClusters@2024-08-12-preview")
    authorization_role_assignments      = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    authorization_locks                 = optional(string, "Microsoft.Authorization/locks@2020-05-01")
  })
  default     = {}
  description = <<DESCRIPTION
AzAPI resource types and API versions used by the module.

- `redhatopenshift_open_shift_clusters` - Resource type and API version for the OpenShift cluster.
- `authorization_role_assignments` - Resource type and API version for private endpoint role assignments.
- `authorization_locks` - Resource type and API version for private endpoint locks.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry configuration applied to every supported AzAPI resource declared by the module and its applicable submodules. Defaults to `null` (no custom retry).

- `error_message_regex`  - (Optional) A list of regex patterns matching error messages that trigger a retry.
- `interval_seconds`     - (Optional) Initial interval between retries in seconds.
- `max_interval_seconds` - (Optional) Maximum interval between retries in seconds.

See <https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource#retry> for full semantics.
DESCRIPTION
}
