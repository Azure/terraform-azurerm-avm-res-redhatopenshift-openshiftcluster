# This variable is used to determine if the private_dns_zone_group block should be included,
# or if it is to be managed externally, e.g. using Azure Policy.
# https://github.com/Azure/terraform-azurerm-avm-res-keyvault-vault/issues/32
# Azure Red Hat OpenShift does not support Azure Private Link endpoints
# Commenting out this variable as it's not applicable to ARO
# variable "private_endpoints_manage_dns_zone_group" {
#   type        = bool
#   default     = true
#   description = "Whether to manage private DNS zone groups with this module. If set to false, you must manage private DNS zone groups externally, e.g. using Azure Policy."
#   nullable    = false
# }

# Azure Red Hat OpenShift specific variables
variable "api_server_profile" {
  type = object({
    visibility = string
  })
  description = <<DESCRIPTION
Configuration for the API server profile.

- `visibility` - (Required) Visibility of the API server. Possible values are `Private` and `Public`.
DESCRIPTION

  validation {
    condition     = contains(["Private", "Public"], var.api_server_profile.visibility)
    error_message = "API server visibility must be either 'Private' or 'Public'."
  }
}

variable "cluster_profile" {
  type = object({
    domain                      = string
    version                     = string
    fips_enabled                = optional(bool, false)
    managed_resource_group_name = optional(string, null)
    pull_secret                 = optional(string, null)
  })
  description = <<DESCRIPTION
Configuration for the OpenShift cluster profile.

- `domain` - (Required) Domain name for the OpenShift cluster.
- `version` - (Required) Version of OpenShift to deploy.
- `fips_enabled` - (Optional) Whether FIPS mode is enabled. Defaults to `false`.
- `managed_resource_group_name` - (Optional) Name of the managed resource group. If not specified, one will be generated.
- `pull_secret` - (Optional) Red Hat pull secret for accessing Red Hat container registries.
DESCRIPTION

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.cluster_profile.domain))
    error_message = "Domain must be between 3 and 63 characters, contain only lowercase letters, numbers, and hyphens, and start and end with alphanumeric characters."
  }
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.cluster_profile.version))
    error_message = "Version must be in semantic version format (e.g., '4.11.0')."
  }
}

variable "ingress_profile" {
  type = object({
    visibility = string
  })
  description = <<DESCRIPTION
Configuration for the ingress profile.

- `visibility` - (Required) Visibility of the ingress. Possible values are `Private` and `Public`.
DESCRIPTION

  validation {
    condition     = contains(["Private", "Public"], var.ingress_profile.visibility)
    error_message = "Ingress visibility must be either 'Private' or 'Public'."
  }
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
  description = <<DESCRIPTION
Configuration for the master node profile.

- `subnet_id` - (Required) The subnet ID for the master nodes.
- `vm_size` - (Required) The VM size for the master nodes.
- `disk_encryption_set_id` - (Optional) The disk encryption set ID for master node disks.
- `encryption_at_host_enabled` - (Optional) Whether encryption at host is enabled for master nodes. Defaults to `false`.
DESCRIPTION

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-f-]+/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.main_profile.subnet_id))
    error_message = "Subnet ID must be a valid Azure subnet resource ID."
  }
}

variable "name" {
  type        = string
  description = "The name of the Azure Red Hat OpenShift cluster."

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]$", var.name))
    error_message = "The name must be between 3 and 63 characters long and can only contain letters, numbers, and hyphens. It must start and end with a letter or number."
  }
}

variable "network_profile" {
  type = object({
    pod_cidr                                     = string
    service_cidr                                 = string
    outbound_type                                = optional(string, "Loadbalancer")
    preconfigured_network_security_group_enabled = optional(bool, false)
  })
  description = <<DESCRIPTION
Configuration for the cluster network profile.

- `pod_cidr` - (Required) CIDR block for pod network.
- `service_cidr` - (Required) CIDR block for service network.
- `outbound_type` - (Optional) Outbound routing method. Possible values are `Loadbalancer` and `UserDefinedRouting`. Defaults to `Loadbalancer`.
- `preconfigured_network_security_group_enabled` - (Optional) Whether to use preconfigured network security groups. Defaults to `false`.
DESCRIPTION

  validation {
    condition     = can(cidrhost(var.network_profile.pod_cidr, 0))
    error_message = "Pod CIDR must be a valid CIDR block."
  }
  validation {
    condition     = can(cidrhost(var.network_profile.service_cidr, 0))
    error_message = "Service CIDR must be a valid CIDR block."
  }
  validation {
    condition     = contains(["Loadbalancer", "UserDefinedRouting"], var.network_profile.outbound_type)
    error_message = "Outbound type must be either 'Loadbalancer' or 'UserDefinedRouting'."
  }
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
  description = <<DESCRIPTION
Configuration for the service principal used by the cluster.

- `client_id` - (Required) The client ID of the service principal.
- `client_secret` - (Required) The client secret of the service principal.
DESCRIPTION
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.service_principal.client_id))
    error_message = "Client ID must be a valid GUID."
  }
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
  description = <<DESCRIPTION
Configuration for the worker node profile.

- `subnet_id` - (Required) The subnet ID for the worker nodes.
- `vm_size` - (Required) The VM size for the worker nodes.
- `node_count` - (Required) The number of worker nodes.
- `disk_size_gb` - (Required) The disk size in GB for worker nodes.
- `disk_encryption_set_id` - (Optional) The disk encryption set ID for worker node disks.
- `encryption_at_host_enabled` - (Optional) Whether encryption at host is enabled for worker nodes. Defaults to `false`.
DESCRIPTION

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-f-]+/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.worker_profile.subnet_id))
    error_message = "Subnet ID must be a valid Azure subnet resource ID."
  }
  validation {
    condition     = var.worker_profile.node_count >= 3 && var.worker_profile.node_count <= 20
    error_message = "Worker node count must be between 3 and 20."
  }
  validation {
    condition     = var.worker_profile.disk_size_gb >= 128
    error_message = "Worker node disk size must be at least 128 GB."
  }
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

variable "diagnostic_settings" {
  type = map(object({
    name                                     = optional(string, null)
    log_categories                           = optional(set(string), [])
    log_groups                               = optional(set(string), ["allLogs"])
    metric_categories                        = optional(set(string), ["AllMetrics"])
    log_analytics_destination_type           = optional(string, "Dedicated")
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of diagnostic settings to create on the Azure Red Hat OpenShift cluster. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the diagnostic setting. One will be generated if not set, however this will not be unique if you want to create multiple diagnostic setting resources.
- `log_categories` - (Optional) A set of log categories to send to the log analytics workspace. Defaults to `[]`.
- `log_groups` - (Optional) A set of log groups to send to the log analytics workspace. Defaults to `["allLogs"]`.
- `metric_categories` - (Optional) A set of metric categories to send to the log analytics workspace. Defaults to `["AllMetrics"]`.
- `log_analytics_destination_type` - (Optional) The destination type for the diagnostic setting. Possible values are `Dedicated` and `AzureDiagnostics`. Defaults to `Dedicated`.
- `workspace_resource_id` - (Optional) The resource ID of the log analytics workspace to send logs and metrics to.
- `storage_account_resource_id` - (Optional) The resource ID of the storage account to send logs and metrics to.
- `event_hub_authorization_rule_resource_id` - (Optional) The resource ID of the event hub authorization rule to send logs and metrics to.
- `event_hub_name` - (Optional) The name of the event hub. If none is specified, the default event hub will be selected.
- `marketplace_partner_resource_id` - (Optional) The full ARM resource ID of the Marketplace resource to which you would like to send Diagnostic LogsLogs.
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for _, v in var.diagnostic_settings : contains(["Dedicated", "AzureDiagnostics"], v.log_analytics_destination_type)])
    error_message = "Log analytics destination type must be one of: 'Dedicated', 'AzureDiagnostics'."
  }
  validation {
    condition = alltrue(
      [
        for _, v in var.diagnostic_settings :
        v.workspace_resource_id != null || v.storage_account_resource_id != null || v.event_hub_authorization_rule_resource_id != null || v.marketplace_partner_resource_id != null
      ]
    )
    error_message = "At least one of `workspace_resource_id`, `storage_account_resource_id`, `marketplace_partner_resource_id`, or `event_hub_authorization_rule_resource_id`, must be set."
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
  nullable    = false
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Controls the Resource Lock configuration for this resource. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "The lock level must be one of: 'None', 'CanNotDelete', or 'ReadOnly'."
  }
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
  description = <<DESCRIPTION
A map of private endpoints to create on this resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the private endpoint. One will be generated if not set.
- `role_assignments` - (Optional) A map of role assignments to create on the private endpoint. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time. See `var.role_assignments` for more information.
- `lock` - (Optional) The lock level to apply to the private endpoint. Default is `None`. Possible values are `None`, `CanNotDelete`, and `ReadOnly`.
- `tags` - (Optional) A mapping of tags to assign to the private endpoint.
- `subnet_resource_id` - The resource ID of the subnet to deploy the private endpoint in.
- `private_dns_zone_group_name` - (Optional) The name of the private DNS zone group. One will be generated if not set.
- `private_dns_zone_resource_ids` - (Optional) A set of resource IDs of private DNS zones to associate with the private endpoint. If not set, no zone groups will be created and the private endpoint will not be associated with any private DNS zones. DNS records must be managed external to this module.
- `application_security_group_resource_ids` - (Optional) A map of resource IDs of application security groups to associate with the private endpoint. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
- `private_service_connection_name` - (Optional) The name of the private service connection. One will be generated if not set.
- `network_interface_name` - (Optional) The name of the network interface. One will be generated if not set.
- `location` - (Optional) The Azure location where the resources will be deployed. Defaults to the location of the resource group.
- `resource_group_name` - (Optional) The resource group where the resources will be deployed. Defaults to the resource group of this resource.
- `ip_configurations` - (Optional) A map of IP configurations to create on the private endpoint. If not specified the platform will create one. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
  - `name` - The name of the IP configuration.
  - `private_ip_address` - The private IP address of the IP configuration.
DESCRIPTION
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
  description = <<DESCRIPTION
A map of role assignments to create on this resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `description` - The description of the role assignment.
- `skip_service_principal_aad_check` - If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
- `condition` - The condition which will be used to scope the role assignment.
- `condition_version` - The version of the condition syntax. Valid values are '2.0'.

> Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.
DESCRIPTION
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
    delete = optional(string, null)
    read   = optional(string, null)
    update = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Timeout configuration for the Azure Red Hat OpenShift cluster resource.

- `create` - (Optional) Timeout for creating the cluster. Defaults to 90 minutes.
- `delete` - (Optional) Timeout for deleting the cluster. Defaults to 90 minutes.
- `read` - (Optional) Timeout for reading the cluster. Defaults to 5 minutes.
- `update` - (Optional) Timeout for updating the cluster. Defaults to 90 minutes.
DESCRIPTION
}
