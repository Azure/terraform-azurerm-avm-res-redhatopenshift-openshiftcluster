resource "azurerm_redhat_openshift_cluster" "this" {
  location            = var.location
  name                = var.name
  resource_group_name = var.resource_group_name
  tags                = var.tags

  api_server_profile {
    visibility = var.api_server_profile.visibility
  }
  cluster_profile {
    domain                      = var.cluster_profile.domain
    version                     = var.cluster_profile.version
    fips_enabled                = var.cluster_profile.fips_enabled
    managed_resource_group_name = var.cluster_profile.managed_resource_group_name
    pull_secret                 = var.cluster_profile.pull_secret
  }
  ingress_profile {
    visibility = var.ingress_profile.visibility
  }
  main_profile {
    subnet_id                  = var.main_profile.subnet_id
    vm_size                    = var.main_profile.vm_size
    disk_encryption_set_id     = var.main_profile.disk_encryption_set_id
    encryption_at_host_enabled = var.main_profile.encryption_at_host_enabled
  }
  network_profile {
    pod_cidr                                     = var.network_profile.pod_cidr
    service_cidr                                 = var.network_profile.service_cidr
    outbound_type                                = var.network_profile.outbound_type
    preconfigured_network_security_group_enabled = var.network_profile.preconfigured_network_security_group_enabled
  }
  service_principal {
    client_id     = var.service_principal.client_id
    client_secret = var.service_principal.client_secret
  }
  worker_profile {
    disk_size_gb               = var.worker_profile.disk_size_gb
    node_count                 = var.worker_profile.node_count
    subnet_id                  = var.worker_profile.subnet_id
    vm_size                    = var.worker_profile.vm_size
    disk_encryption_set_id     = var.worker_profile.disk_encryption_set_id
    encryption_at_host_enabled = var.worker_profile.encryption_at_host_enabled
  }
  dynamic "timeouts" {
    for_each = var.timeouts != null ? [var.timeouts] : []

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
#   scope      = azurerm_redhat_openshift_cluster.this.id
#   notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
# }

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azurerm_redhat_openshift_cluster.this.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  description                            = each.value.description
  principal_type                         = each.value.principal_type
  role_definition_id                     = startswith(each.value.role_definition_id_or_name, "/") ? each.value.role_definition_id_or_name : null
  role_definition_name                   = startswith(each.value.role_definition_id_or_name, "/") ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}
