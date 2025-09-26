variable "api_server_profile" {
  type = object({
    visibility = string
  })
  description = "API server profile configuration."
}

variable "cluster_profile" {
  type = object({
    domain                 = string
    version                = string
    pull_secret            = optional(string)
    fips_validated_modules = optional(bool, false)
    resource_group_id      = optional(string)
    oidc_issuer            = optional(string)
  })
  description = "Cluster-level settings."
}

variable "identity_ids" {
  type        = list(string)
  default     = []
  description = "List of user-assigned managed identity resource IDs to attach when using user-assigned identities."

  validation {
    condition     = var.identity != null ? true : length(var.identity_ids) > 0
    error_message = "Provide at least one user-assigned identity via identity_ids when no explicit identity block is supplied."
  }
}

variable "identity" {
  type = object({
    type                       = string
    user_assigned_identity_ids = optional(list(string))
  })
  default     = null
  description = "Full managed identity configuration. When omitted, the module assumes a user-assigned identity using identity_ids."

  validation {
    condition = (
      var.identity == null
      ? true
      : (
        contains(["None", "SystemAssigned", "UserAssigned", "SystemAssigned,UserAssigned"], var.identity.type)
        && (
          length(regexall("UserAssigned", var.identity.type)) == 0
          || length(try(var.identity.user_assigned_identity_ids, [])) > 0
        )
      )
    )
    error_message = "identity.type must be one of None, SystemAssigned, UserAssigned, or SystemAssigned,UserAssigned. When type includes UserAssigned, supply at least one user_assigned_identity_ids entry."
  }
}

variable "location" {
  type        = string
  description = "Azure region where the cluster is deployed."
}

variable "main_profile" {
  type = object({
    subnet_id                  = string
    vm_size                    = string
    encryption_at_host_enabled = optional(bool, false)
    disk_encryption_set_id     = optional(string)
  })
  description = "Control-plane (master) profile configuration."
}

variable "name" {
  type        = string
  description = "Name of the Azure Red Hat OpenShift cluster."
}

variable "network_profile" {
  type = object({
    pod_cidr                                     = string
    service_cidr                                 = string
    outbound_type                                = optional(string, "Loadbalancer")
    preconfigured_network_security_group_enabled = optional(bool, false)
    lb_managed_outbound_ip_count                 = optional(number)
  })
  description = "Network configuration for the cluster."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group hosting the cluster."
}

variable "worker_profile" {
  type = object({
    node_count                 = number
    subnet_id                  = string
    vm_size                    = string
    disk_size_gb               = optional(number, 128)
    encryption_at_host_enabled = optional(bool, false)
    disk_encryption_set_id     = optional(string)
    name                       = optional(string, "worker")
  })
  description = "Worker node profile configuration."
}

variable "worker_profiles" {
  type = list(object({
    node_count                 = number
    subnet_id                  = string
    vm_size                    = string
    disk_size_gb               = optional(number, 128)
    encryption_at_host_enabled = optional(bool, false)
    disk_encryption_set_id     = optional(string)
    name                       = optional(string, "worker")
  }))
  default     = []
  description = "Optional list of worker node profile configurations. When set, overrides worker_profile."
}

variable "api_version" {
  type        = string
  default     = "2024-08-12-preview"
  description = "ARM API version for Microsoft.RedHatOpenShift/openShiftClusters."
}

variable "diagnostic_settings" {
  type = map(object({
    name                                     = optional(string)
    event_hub_authorization_rule_resource_id = optional(string)
    event_hub_name                           = optional(string)
    log_analytics_destination_type           = optional(string)
    workspace_resource_id                    = optional(string)
    marketplace_partner_resource_id          = optional(string)
    storage_account_resource_id              = optional(string)
    log_categories                           = optional(list(string), [])
    log_groups                               = optional(list(string), [])
    metric_categories                        = optional(list(string), [])
  }))
  default     = {}
  description = "Diagnostic settings to configure on the cluster resource."
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "ingress_profiles" {
  type = list(object({
    name       = string
    visibility = string
  }))
  default     = [{ name = "default", visibility = "Public" }]
  description = "Ingress profile configurations."
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string)
  })
  default     = null
  description = "Management lock configuration."
}

variable "platform_workload_identities" {
  type        = map(string)
  default     = {}
  description = "Map of ARO platform operator name to user-assigned managed identity resource ID."
}

variable "platform_workload_identity_upgradeable_to" {
  type        = string
  default     = null
  description = "Optional OpenShift version that the workload identity platform can upgrade to."
}

variable "role_assignments" {
  type = map(object({
    principal_id                           = string
    role_definition_id_or_name             = string
    condition                              = optional(string)
    condition_version                      = optional(string)
    delegated_managed_identity_resource_id = optional(string)
    skip_service_principal_aad_check       = optional(bool)
  }))
  default     = {}
  description = "Role assignments to create on the cluster resource."
}

variable "service_principal" {
  type = object({
    client_id     = string
    client_secret = string
  })
  default     = null
  description = "Optional service principal credentials for legacy deployments."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to the cluster resource."
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = "Custom timeouts for create/read/update/delete operations."
}
