data "azapi_client_config" "current" {}

locals {
  identity_type = local.managed_identities_defaults.system_assigned && length(local.managed_identities_defaults.user_assigned_resource_ids) > 0 ? "SystemAssigned, UserAssigned" : (
    local.managed_identities_defaults.system_assigned ? "SystemAssigned" : (
      length(local.managed_identities_defaults.user_assigned_resource_ids) > 0 ? "UserAssigned" : null
    )
  )
  managed_identities_defaults = merge({
    system_assigned            = false
    user_assigned_resource_ids = []
  }, var.managed_identities)
  managed_resource_group_id = format(
    "/subscriptions/%s/resourcegroups/%s",
    data.azapi_client_config.current.subscription_id,
    local.managed_resource_group_name,
  )
  managed_resource_group_name = length(local.requested_managed_resource_group_name) > 0 ? local.requested_managed_resource_group_name : format("rg-%s", var.name)
  platform_workload_identity_profile = local.platform_workload_identity_profile_enabled ? {
    platformWorkloadIdentities = {
      for name, identity in var.platform_workload_identities : name => merge(
        {
          resourceId = identity.resource_id
        },
        identity.federated_identity_client_id == null ? {} : {
          federatedIdentityClientId = identity.federated_identity_client_id
        }
      )
    }
  } : {}
  platform_workload_identity_profile_enabled = length(var.platform_workload_identities) > 0
  requested_managed_resource_group_name      = try(trimspace(coalesce(var.cluster_profile.managed_resource_group_name, "")), "")
  resource_group_id = format(
    "/subscriptions/%s/resourceGroups/%s",
    data.azapi_client_config.current.subscription_id,
    var.resource_group_name,
  )
}

resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = local.resource_group_id
  type      = "Microsoft.RedHatOpenShift/openShiftClusters@2024-08-12-preview"
  body = {
    properties = merge({
      apiserverProfile = {
        visibility = var.api_server_profile.visibility
      }
      clusterProfile = merge({
        domain               = var.cluster_profile.domain
        version              = var.cluster_profile.version
        fipsValidatedModules = var.cluster_profile.fips_enabled ? "Enabled" : "Disabled"
        resourceGroupId      = local.managed_resource_group_id
        },
        var.cluster_profile.pull_secret != null ? { pullSecret = var.cluster_profile.pull_secret } : {},
      )
      ingressProfiles = [{
        name       = "default"
        visibility = var.ingress_profile.visibility
      }]
      masterProfile = merge({
        subnetId         = var.main_profile.subnet_id
        vmSize           = var.main_profile.vm_size
        encryptionAtHost = var.main_profile.encryption_at_host_enabled ? "Enabled" : "Disabled"
        },
        var.main_profile.disk_encryption_set_id != null ? { diskEncryptionSetId = var.main_profile.disk_encryption_set_id } : {},
      )
      networkProfile = merge({
        podCidr          = var.network_profile.pod_cidr
        serviceCidr      = var.network_profile.service_cidr
        preconfiguredNSG = var.network_profile.preconfigured_network_security_group_enabled ? "Enabled" : "Disabled"
        },
        var.network_profile.outbound_type != null ? { outboundType = var.network_profile.outbound_type } : {},
      )
      workerProfiles = [merge({
        name             = "worker"
        subnetId         = var.worker_profile.subnet_id
        vmSize           = var.worker_profile.vm_size
        diskSizeGB       = var.worker_profile.disk_size_gb
        count            = var.worker_profile.node_count
        encryptionAtHost = var.worker_profile.encryption_at_host_enabled ? "Enabled" : "Disabled"
        },
        var.worker_profile.disk_encryption_set_id != null ? { diskEncryptionSetId = var.worker_profile.disk_encryption_set_id } : {},
      )]
      },
      can(var.service_principal) ? {
        servicePrincipalProfile = {
          clientId     = var.service_principal.client_id
          clientSecret = var.service_principal.client_secret
        }
      } : {},
      local.platform_workload_identity_profile_enabled ? {
        platformWorkloadIdentityProfile = local.platform_workload_identity_profile
      } : {}
    )
  }
  create_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers   = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  tags           = var.tags
  update_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  dynamic "identity" {
    for_each = local.identity_type == null ? [] : [local.identity_type]

    content {
      type         = identity.value
      identity_ids = length(local.managed_identities_defaults.user_assigned_resource_ids) > 0 ? local.managed_identities_defaults.user_assigned_resource_ids : null
    }
  }
  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

#   lock_level = var.lock.kind
#   name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
#   scope      = azapi_resource.this.id
#   notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
# }

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azapi_resource.this.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  description                            = each.value.description
  principal_type                         = each.value.principal_type
  role_definition_id                     = startswith(each.value.role_definition_id_or_name, "/") ? each.value.role_definition_id_or_name : null
  role_definition_name                   = startswith(each.value.role_definition_id_or_name, "/") ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}
