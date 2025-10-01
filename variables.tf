# -----------------------------------------------------------------------------
# ARO specific profile objects (missing in template scaffold). Added so module
# variables referenced in main.tf are defined and consumer example works.
# -----------------------------------------------------------------------------

variable "api_server_profile" {
  type = object({
    visibility = string
  })
  description = "API server profile configuration: visibility (Public or Private)."
}

variable "cluster_profile" {
  type = object({
    domain                      = string
    version                     = string
    fips_enabled                = optional(bool, false)
    managed_resource_group_name = optional(string, null)
    pull_secret                 = optional(string, null)
  })
  description = "Cluster profile settings: domain, version, optional FIPS, managed RG and pull secret."
}

variable "ingress_profile" {
  type = object({
    visibility = string
  })
  description = "Ingress profile configuration: visibility (Public or Private)."
}

variable "location" {
  type        = string
  description = "Azure region where the resource should be deployed."
  nullable    = false
}

variable "main_profile" {
  type = object({
    subnet_id                  = string
    vm_size                    = string
    disk_encryption_set_id     = optional(string, null)
    encryption_at_host_enabled = optional(bool, false)
  })
  description = "Master (control plane) profile: subnet id, vm size and optional encryption settings."
}

variable "name" {
  type        = string
  description = "The name of the ARO cluster resource. Must be 5-50 chars, lowercase letters, numbers or hyphens, start/end with alphanumeric."

  # Replace placeholder validation with a realistic pattern.
  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]{3,48})[a-z0-9]$", var.name))
    error_message = "Name must be 5-50 chars, lowercase letters, numbers or hyphens; cannot start/end with hyphen."
  }
}

variable "network_profile" {
  type = object({
    pod_cidr                                     = string
    service_cidr                                 = string
    outbound_type                                = optional(string, null) # Loadbalancer | UserDefinedRouting
    preconfigured_network_security_group_enabled = optional(bool, false)
  })
  description = "Network profile: pod/service CIDRs, outbound type and optional preconfigured NSG flag."
}

# This is required for most resource modules
variable "resource_group_name" {
  type        = string
  description = "The resource group where the resources will be deployed."
}

variable "service_principal" {
  type = object({
    client_id     = string
    client_secret = string
  })
  description = "Service principal credentials used by the ARO cluster."
  sensitive   = true
}

variable "worker_profile" {
  type = object({
    subnet_id                  = string
    vm_size                    = string
    node_count                 = number
    disk_size_gb               = number
    disk_encryption_set_id     = optional(string, null)
    encryption_at_host_enabled = optional(bool, false)
  })
  description = "Worker node pool profile: sizing and encryption options."
}

# required AVM interfaces
# remove only if not supported by the resource
# tflint-ignore: terraform_unused_declarations
variable "customer_managed_key" {
  type = object({
    key_vault_resource_id = string
    key_name              = string
    key_version           = optional(string, null)
    user_assigned_identity = optional(object({
      resource_id = string
    }), null)
  })
  default     = null
  description = <<DESCRIPTION
A map describing customer-managed keys to associate with the resource. This includes the following properties:
- `key_vault_resource_id` - The resource ID of the Key Vault where the key is stored.
- `key_name` - The name of the key.
- `key_version` - (Optional) The version of the key. If not specified, the latest version is used.
- `user_assigned_identity` - (Optional) An object representing a user-assigned identity with the following properties:
  - `resource_id` - The resource ID of the user-assigned identity.
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
  nullable    = false
}

# tflint-ignore: terraform_unused_declarations
variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Controls the Managed Identity configuration on this resource. The following properties can be specified:

- `system_assigned` - (Optional) Specifies if the System Assigned Managed Identity should be enabled.
- `user_assigned_resource_ids` - (Optional) Specifies a list of User Assigned Managed Identity resource IDs to be assigned to this resource.
DESCRIPTION
  nullable    = false
}

variable "private_endpoints" {
  type = map(object({
    name = optional(string, null)
    role_assignments = optional(map(object({
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
      principal_type                         = optional(string, null)
    })), {})
    lock = optional(object({
      kind = string
      name = optional(string, null)
    }), null)
    tags                                    = optional(map(string), null)
    subnet_resource_id                      = string
    private_dns_zone_group_name             = optional(string, "default")
    private_dns_zone_resource_ids           = optional(set(string), [])
    application_security_group_associations = optional(map(string), {})
    private_service_connection_name         = optional(string, null)
    network_interface_name                  = optional(string, null)
    location                                = optional(string, null)
    resource_group_name                     = optional(string, null)
    ip_configurations = optional(map(object({
      name               = string
      private_ip_address = string
    })), {})
  }))
  default     = {}
  description = "A map of private endpoints to create on this resource."
  nullable    = false
}

# This variable is used to determine if the private_dns_zone_group block should be included,
# or if it is to be managed externally, e.g. using Azure Policy.
# https://github.com/Azure/terraform-azurerm-avm-res-keyvault-vault/issues/32
# Alternatively you can use AzAPI, which does not have this issue.
variable "private_endpoints_manage_dns_zone_group" {
  type        = bool
  default     = true
  description = "Whether to manage private DNS zone groups with this module. If set to false, you must manage private DNS zone groups externally, e.g. using Azure Policy."
  nullable    = false
}

variable "role_assignments" {
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default     = {}
  description = "A map of role assignments to create on this resource."
  nullable    = false
}

# tflint-ignore: terraform_unused_declarations
variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}

variable "timeouts" {
  type = object({
    create = optional(string, null)
    read   = optional(string, null)
    update = optional(string, null)
    delete = optional(string, null)
  })
  default     = null
  description = "Resource operation timeouts for create, read, update, delete (e.g. 120m). Optional."
}
