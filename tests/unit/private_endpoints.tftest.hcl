mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000000"
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [{
          role_name = "Reader"
          id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        }]
      }
    }
  }
  mock_resource "azapi_resource" {
    defaults = {
      id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.RedHatOpenShift/openShiftClusters/aro-test"
      output = {}
    }
  }
}

mock_provider "azurerm" {
  mock_resource "azurerm_private_endpoint" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/privateEndpoints/pe-test"
    }
  }
}

mock_provider "modtm" {}

mock_provider "random" {
  mock_resource "random_uuid" {
    defaults = {
      result = "00000000-0000-0000-0000-000000000001"
    }
  }
}

variables {
  name                = "aro-test"
  location            = "eastus"
  resource_group_name = "test"
  subscription_id     = "00000000-0000-0000-0000-000000000000"
  enable_telemetry    = false
  api_server_profile  = { visibility = "Private" }
  ingress_profile     = { visibility = "Private" }
  cluster_profile     = { domain = "arotest", version = "4.16.39" }
  main_profile = {
    subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/test/subnets/master"
    vm_size   = "Standard_D8s_v3"
  }
  worker_profile = {
    subnet_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/test/subnets/worker"
    vm_size      = "Standard_D4s_v3"
    node_count   = 3
    disk_size_gb = 128
  }
  network_profile = { pod_cidr = "10.128.0.0/14", service_cidr = "172.30.0.0/16" }
}

run "empty_defaults" {
  command = apply
  providers = {
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
  }
  assert {
    condition = (
      length(azurerm_private_endpoint.this_managed_dns_zone_groups) == 0 &&
      length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups) == 0 &&
      length(azapi_resource.private_endpoint_role_assignments) == 0 &&
      length(azapi_resource.private_endpoint_locks) == 0 &&
      length(azurerm_role_assignment.this) == 0
    )
    error_message = "Omitting endpoints must not create endpoints, locks, or role assignments."
  }
}

run "managed_dns_and_custom_ip_fields" {
  command = apply
  providers = {
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
  }
  variables {
    private_endpoints = {
      api = {
        name                            = "custom-endpoint"
        location                        = "westus2"
        resource_group_name             = "endpoint-rg"
        network_interface_name          = "custom-nic"
        private_service_connection_name = "custom-connection"
        tags                            = { purpose = "endpoint" }
        subnet_resource_id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/test/subnets/endpoint"
        subresource_name                = "api"
        private_dns_zone_group_name     = "custom"
        private_dns_zone_resource_ids   = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/privateDnsZones/test.internal"]
        ip_configurations = {
          fixed = { name = "fixed", private_ip_address = "10.0.3.10", member_name = "custom-member" }
        }
      }
    }
  }
  assert {
    condition = (
      length(azurerm_private_endpoint.this_managed_dns_zone_groups) == 1 &&
      length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups) == 0 &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["api"].private_service_connection[0].subresource_names == tolist(["api"]) &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["api"].ip_configuration[0].member_name == "custom-member" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["api"].ip_configuration[0].subresource_name == "api" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["api"].private_dns_zone_group[0].name == "custom" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["api"].name == "custom-endpoint" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["api"].location == "westus2" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["api"].resource_group_name == "endpoint-rg" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["api"].custom_network_interface_name == "custom-nic" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["api"].private_service_connection[0].name == "custom-connection" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["api"].tags["purpose"] == "endpoint" &&
      length(output.private_endpoints) == 1
    )
    error_message = "Managed DNS must create exactly one endpoint and honor the DNS, group, member, and output fields."
  }
}

run "unmanaged_dns_extensions" {
  command = apply
  providers = {
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
  }
  variables {
    private_endpoints_manage_dns_zone_group = false
    private_endpoints = {
      api = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/test/subnets/endpoint"
        lock               = { kind = "CanNotDelete", name = "endpoint-lock", notes = "Keep this endpoint" }
        role_assignments = {
          reader = {
            name                                   = "00000000-0000-0000-0000-000000000002"
            role_definition_id_or_name             = "Reader"
            principal_id                           = "00000000-0000-0000-0000-000000000003"
            principal_type                         = "ServicePrincipal"
            skip_service_principal_aad_check       = true
            description                            = "Endpoint reader"
            condition                              = "example"
            condition_version                      = "2.0"
            delegated_managed_identity_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/delegated"
          }
        }
        application_security_group_associations = {
          app = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/applicationSecurityGroups/app"
        }
        ip_configurations = {
          fixed = { name = "fixed", private_ip_address = "10.0.3.10" }
        }
      }
    }
    retry    = { error_message_regex = ["ScopeLocked"], interval_seconds = 5, max_interval_seconds = 30 }
    timeouts = { create = "20m", read = "5m", update = "20m", delete = "10m" }
  }
  assert {
    condition = (
      length(azurerm_private_endpoint.this_managed_dns_zone_groups) == 0 &&
      length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups) == 1 &&
      length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["api"].private_dns_zone_group) == 0 &&
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["api"].private_service_connection[0].subresource_names == tolist(["cluster"]) &&
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["api"].ip_configuration[0].member_name == "cluster" &&
      azurerm_private_endpoint_application_security_group_association.this["api-app"].private_endpoint_id == azurerm_private_endpoint.this_unmanaged_dns_zone_groups["api"].id &&
      output.private_endpoints["api"].id == azurerm_private_endpoint.this_unmanaged_dns_zone_groups["api"].id
    )
    error_message = "DNS-off must create only the unmanaged address and preserve legacy group/member defaults and association/output selection."
  }
  assert {
    condition = (
      azapi_resource.private_endpoint_locks["api"].name == "endpoint-lock" &&
      azapi_resource.private_endpoint_locks["api"].parent_id == azurerm_private_endpoint.this_unmanaged_dns_zone_groups["api"].id &&
      azapi_resource.private_endpoint_locks["api"].body.properties.level == "CanNotDelete" &&
      azapi_resource.private_endpoint_locks["api"].body.properties.notes == "Keep this endpoint" &&
      azapi_resource.private_endpoint_locks["api"].retry.interval_seconds == 5 &&
      azapi_resource.private_endpoint_locks["api"].timeouts.create == "20m"
    )
    error_message = "Endpoint locks must honor name, level, notes, scope, retry, and timeouts."
  }
  assert {
    condition = (
      azapi_resource.private_endpoint_role_assignments["api-reader"].name == "00000000-0000-0000-0000-000000000002" &&
      azapi_resource.private_endpoint_role_assignments["api-reader"].parent_id == azurerm_private_endpoint.this_unmanaged_dns_zone_groups["api"].id &&
      azapi_resource.private_endpoint_role_assignments["api-reader"].body.properties.principalId == "00000000-0000-0000-0000-000000000003" &&
      azapi_resource.private_endpoint_role_assignments["api-reader"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7" &&
      azapi_resource.private_endpoint_role_assignments["api-reader"].body.properties.principalType == "ServicePrincipal" &&
      azapi_resource.private_endpoint_role_assignments["api-reader"].body.properties.description == "Endpoint reader" &&
      azapi_resource.private_endpoint_role_assignments["api-reader"].body.properties.condition == "example" &&
      azapi_resource.private_endpoint_role_assignments["api-reader"].body.properties.conditionVersion == "2.0" &&
      azapi_resource.private_endpoint_role_assignments["api-reader"].body.properties.delegatedManagedIdentityResourceId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/delegated" &&
      azapi_resource.private_endpoint_role_assignments["api-reader"].retry.max_interval_seconds == 30 &&
      azapi_resource.private_endpoint_role_assignments["api-reader"].timeouts.delete == "10m"
    )
    error_message = "Endpoint assignments must honor every permission field and use the endpoint scope."
  }
}

run "managed_dns_optional_extension_names" {
  command = apply
  providers = {
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
  }
  variables {
    private_endpoints = {
      api = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/test/subnets/endpoint"
        lock               = { kind = "ReadOnly" }
        role_assignments = {
          reader = {
            role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            principal_id               = "00000000-0000-0000-0000-000000000003"
          }
        }
      }
    }
    enable_telemetry = true
    role_assignments = {
      cluster_reader = {
        role_definition_id_or_name = "Reader"
        principal_id               = "00000000-0000-0000-0000-000000000003"
        principal_type             = "ServicePrincipal"
      }
    }
  }
  assert {
    condition = (
      azapi_resource.private_endpoint_locks["api"].name == "lock-ReadOnly" &&
      azapi_resource.private_endpoint_locks["api"].parent_id == azurerm_private_endpoint.this_managed_dns_zone_groups["api"].id &&
      azapi_resource.private_endpoint_role_assignments["api-reader"].name == "00000000-0000-0000-0000-000000000001" &&
      azapi_resource.private_endpoint_role_assignments["api-reader"].parent_id == azurerm_private_endpoint.this_managed_dns_zone_groups["api"].id &&
      azapi_resource.private_endpoint_role_assignments["api-reader"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["api"].name == "pe-aro-test" &&
      azurerm_private_endpoint.this_managed_dns_zone_groups["api"].private_service_connection[0].name == "pse-aro-test" &&
      azurerm_role_assignment.this["cluster_reader"].scope == azapi_resource.this.id &&
      azurerm_role_assignment.this["cluster_reader"].role_definition_name == "Reader" &&
      azurerm_role_assignment.this["cluster_reader"].principal_id == "00000000-0000-0000-0000-000000000003"
    )
    error_message = "Omitted extension names must receive usable defaults without changing assignment scope or permission."
  }
}

run "invalid_subnet" {
  command = plan
  providers = {
    azapi   = azapi
    azurerm = azurerm
    modtm   = modtm
    random  = random
  }
  variables {
    private_endpoints = { api = { subnet_resource_id = "invalid" } }
  }
  expect_failures = [var.private_endpoints]
}
