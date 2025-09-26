locals {
  fips_flag = var.cluster_profile.fips_validated_modules ? "Enabled" : "Disabled"
  cluster_profile_body = merge(
    {
      domain               = var.cluster_profile.domain
      version              = var.cluster_profile.version
      fipsValidatedModules = local.fips_flag
    },
    var.cluster_profile.pull_secret == null ? {} : { pullSecret = var.cluster_profile.pull_secret },
    var.cluster_profile.resource_group_id == null ? {} : { resourceGroupId = var.cluster_profile.resource_group_id },
    var.cluster_profile.oidc_issuer == null ? {} : { oidcIssuer = var.cluster_profile.oidc_issuer }
  )
  ehost_flag = var.main_profile.encryption_at_host_enabled ? "Enabled" : "Disabled"
  master_profile_body = merge(
    {
      vmSize           = var.main_profile.vm_size
      subnetId         = var.main_profile.subnet_id
      encryptionAtHost = local.ehost_flag
    },
    var.main_profile.disk_encryption_set_id == null ? {} : { diskEncryptionSetId = var.main_profile.disk_encryption_set_id }
  )
  nsg_flag = var.network_profile.preconfigured_network_security_group_enabled ? "Enabled" : "Disabled"
  network_profile_body = merge(
    {
      podCidr          = var.network_profile.pod_cidr
      serviceCidr      = var.network_profile.service_cidr
      outboundType     = var.network_profile.outbound_type
      preconfiguredNSG = local.nsg_flag
    },
    var.network_profile.lb_managed_outbound_ip_count == null ? {} : {
      loadBalancerProfile = {
        managedOutboundIps = {
          count = var.network_profile.lb_managed_outbound_ip_count
        }
      }
    }
  )
  resolved_platform_workload_identities = {
    for k, v in var.platform_workload_identities : k => { resourceId = v }
  }
  platform_workload_identity_profile = (
    length(local.resolved_platform_workload_identities) == 0
    && var.platform_workload_identity_upgradeable_to == null
    ) ? null : merge(
    length(local.resolved_platform_workload_identities) == 0 ? {} : { platformWorkloadIdentities = local.resolved_platform_workload_identities },
    var.platform_workload_identity_upgradeable_to == null ? {} : { upgradeableTo = var.platform_workload_identity_upgradeable_to }
  )
  service_principal_profile = var.service_principal == null ? null : {
    clientId     = var.service_principal.client_id
    clientSecret = var.service_principal.client_secret
  }
  default_worker_profile = {
    name                       = var.worker_profile.name
    node_count                 = var.worker_profile.node_count
    disk_size_gb               = var.worker_profile.disk_size_gb
    vm_size                    = var.worker_profile.vm_size
    subnet_id                  = var.worker_profile.subnet_id
    encryption_at_host_enabled = var.worker_profile.encryption_at_host_enabled
    disk_encryption_set_id     = var.worker_profile.disk_encryption_set_id
  }
  effective_worker_profiles = length(var.worker_profiles) > 0 ? [
    for wp in var.worker_profiles : {
      name                       = coalesce(wp.name, "worker")
      node_count                 = wp.node_count
      disk_size_gb               = coalesce(wp.disk_size_gb, 128)
      vm_size                    = wp.vm_size
      subnet_id                  = wp.subnet_id
      encryption_at_host_enabled = coalesce(wp.encryption_at_host_enabled, false)
      disk_encryption_set_id     = wp.disk_encryption_set_id
    }
  ] : [local.default_worker_profile]
  worker_profiles_body = [
    for wp in local.effective_worker_profiles : merge(
      {
        name             = wp.name
        count            = wp.node_count
        diskSizeGB       = wp.disk_size_gb
        vmSize           = wp.vm_size
        subnetId         = wp.subnet_id
        encryptionAtHost = wp.encryption_at_host_enabled ? "Enabled" : "Disabled"
      },
      wp.disk_encryption_set_id == null ? {} : { diskEncryptionSetId = wp.disk_encryption_set_id }
    )
  ]
  resolved_identity = var.identity != null ? {
    type         = var.identity.type
    identity_ids = try(var.identity.user_assigned_identity_ids, [])
    } : {
    type         = "UserAssigned"
    identity_ids = var.identity_ids
  }
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# --- ARO cluster via AzAPI (preview API for MI/WorkloadIdentity features) ---
resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = data.azurerm_resource_group.rg.id
  type      = "Microsoft.RedHatOpenShift/openShiftClusters@${var.api_version}"
  # Full body mirrors the preview ARM schema
  body = {
    properties = {
      apiserverProfile = {
        visibility = var.api_server_profile.visibility
      }

      clusterProfile = local.cluster_profile_body

      ingressProfiles = [
        for ip in var.ingress_profiles : {
          name       = ip.name
          visibility = ip.visibility
        }
      ]

      masterProfile = local.master_profile_body

      workerProfiles = local.worker_profiles_body

      networkProfile = local.network_profile_body

      platformWorkloadIdentityProfile = local.platform_workload_identity_profile

      servicePrincipalProfile = local.service_principal_profile
    }
  }
  create_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers   = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  # Surface ID and key properties for downstream outputs
  response_export_values = ["id", "properties"]
  tags                   = var.tags
  update_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  # Managed identity configuration
  identity {
    type         = local.resolved_identity.type
    identity_ids = local.resolved_identity.identity_ids
  }
  timeouts {
    create = try(var.timeouts.create, null)
    delete = try(var.timeouts.delete, null)
    read   = try(var.timeouts.read, null)
    update = try(var.timeouts.update, null)
  }

  lifecycle {
    # prevent replacement when optional fields flip null<->object
    ignore_changes = [body.properties.networkProfile.loadBalancerProfile]
  }
}

# Expose the resource ID consistently
locals {
  cluster_api_server_url = try(local.cluster_properties.apiserverProfile.url, null)
  cluster_console_url    = try(local.cluster_properties.consoleProfile.url, null)
  cluster_domain         = try(local.cluster_properties.clusterProfile.domain, null)
  cluster_id             = azapi_resource.this.id
  cluster_properties     = try(azapi_resource.this.output.properties, null)
}

# --- AVM: Management lock ---
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = local.cluster_id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

# --- AVM: Role assignments on the cluster ---
locals {
  role_definition_resource_substring = "/providers/microsoft.authorization/roledefinitions"
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = local.cluster_id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}

# --- AVM: Diagnostics ---
resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.diagnostic_settings

  name                           = each.value.name != null ? each.value.name : "diag-${var.name}"
  target_resource_id             = local.cluster_id
  eventhub_authorization_rule_id = each.value.event_hub_authorization_rule_resource_id
  eventhub_name                  = each.value.event_hub_name
  log_analytics_destination_type = each.value.log_analytics_destination_type
  log_analytics_workspace_id     = each.value.workspace_resource_id
  partner_solution_id            = each.value.marketplace_partner_resource_id
  storage_account_id             = each.value.storage_account_resource_id

  dynamic "enabled_log" {
    for_each = each.value.log_categories

    content {
      category = enabled_log.value
    }
  }
  dynamic "enabled_log" {
    for_each = each.value.log_groups

    content {
      category_group = enabled_log.value
    }
  }
  dynamic "metric" {
    for_each = each.value.metric_categories

    content {
      category = metric.value
      enabled  = true
    }
  }
}
