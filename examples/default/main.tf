terraform {
  required_version = "~> 1.5"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.6"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    modtm = {
      source  = "Azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

# --- Required locals & random string suffix ---
locals {
  region       = var.location
  rp_object_id = var.aro_rp_object_id != null ? var.aro_rp_object_id : try(data.azuread_service_principal.aro_rp[0].object_id, null)
}

resource "random_string" "sfx" {
  length  = 6
  special = false
  upper   = false
}

# Ensure RP is registered
resource "azapi_resource_action" "redhatopenshift_registration" {
  action      = "providers/Microsoft.RedHatOpenShift/register"
  method      = "POST"
  resource_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  type        = "Microsoft.Resources/subscriptions@2021-04-01"
}

locals {
  cluster_identity_name       = "aro-cluster-${local.identity_suffix}"
  cluster_resource_group_id   = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${local.cluster_resource_group_name}"
  cluster_resource_group_name = "aro-cluster-rg-${local.identity_suffix}"
  identity_suffix             = random_string.sfx.result
  # Base platform MIs; add route-table RBAC where required for UDR
  platform_identity_specs = {
    "cloud-controller-manager" = {
      name = "aro-cloud-controller-manager-${local.identity_suffix}"
      assignments = [
        { scope_key = "master_subnet", role_definition_id = local.role_definition_ids.cloud_controller_manager },
        { scope_key = "worker_subnet", role_definition_id = local.role_definition_ids.cloud_controller_manager },
        { scope_key = "master_subnet", role_definition_id = local.role_definition_ids.rp_network_contributor },
        { scope_key = "worker_subnet", role_definition_id = local.role_definition_ids.rp_network_contributor },
        { scope_key = "route_table", role_definition_id = local.role_definition_ids.rp_network_contributor },
        { scope_key = "nat_gateway", role_definition_id = local.role_definition_ids.rp_network_contributor },
      ]
    }

    ingress = {
      name = "aro-ingress-${local.identity_suffix}"
      assignments = [
        { scope_key = "master_subnet", role_definition_id = local.role_definition_ids.ingress },
        { scope_key = "worker_subnet", role_definition_id = local.role_definition_ids.ingress },
        { scope_key = "route_table", role_definition_id = local.role_definition_ids.reader },
      ]
    }

    "machine-api" = {
      name = "aro-machine-api-${local.identity_suffix}"
      assignments = [
        { scope_key = "master_subnet", role_definition_id = local.role_definition_ids.machine_api },
        { scope_key = "worker_subnet", role_definition_id = local.role_definition_ids.machine_api },
        { scope_key = "route_table", role_definition_id = local.role_definition_ids.reader },
      ]
    }

    "cloud-network-config" = {
      name = "aro-cloud-network-config-${local.identity_suffix}"
      assignments = [
        { scope_key = "virtual_network", role_definition_id = local.role_definition_ids.cloud_network_config },
        { scope_key = "route_table", role_definition_id = local.role_definition_ids.rp_network_contributor },
      ]
    }

    "file-csi-driver" = {
      name = "aro-file-csi-driver-${local.identity_suffix}"
      assignments = [
        { scope_key = "virtual_network", role_definition_id = local.role_definition_ids.file_csi_driver },
        { scope_key = "route_table", role_definition_id = local.role_definition_ids.rp_network_contributor },
        { scope_key = "nat_gateway", role_definition_id = local.role_definition_ids.rp_network_contributor },
      ]
    }

    "image-registry" = {
      name = "aro-image-registry-${local.identity_suffix}"
      assignments = [
        { scope_key = "virtual_network", role_definition_id = local.role_definition_ids.image_registry },
        { scope_key = "route_table", role_definition_id = local.role_definition_ids.reader },
      ]
    }

    "aro-operator" = {
      name = "aro-operator-${local.identity_suffix}"
      assignments = [
        { scope_key = "master_subnet", role_definition_id = local.role_definition_ids.aro_operator },
        { scope_key = "worker_subnet", role_definition_id = local.role_definition_ids.aro_operator },
        { scope_key = "route_table", role_definition_id = local.role_definition_ids.rp_network_contributor },
        { scope_key = "nat_gateway", role_definition_id = local.role_definition_ids.rp_network_contributor },
      ]
    }

    "disk-csi-driver" = {
      name = "aro-disk-csi-driver-${local.identity_suffix}"
      assignments = [
        { scope_key = "route_table", role_definition_id = local.role_definition_ids.reader },
      ]
    }
  }
  role_definition_ids = merge(
    {
      federated_credential      = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/ef318e2a-8334-4a05-9e4a-295a196c6a6e"
      managed_identity_operator = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/f1a07417-d97a-45cb-824c-7a7467783830"
      cloud_controller_manager  = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/a1f96423-95ce-4224-ab27-4e3dc72facd4"
      ingress                   = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/0336e1d3-7a87-462b-b6db-342b63f7802c"
      machine_api               = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/0358943c-7e01-48ba-8889-02cc51d78637"
      cloud_network_config      = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/be7a6435-15ae-4171-8f30-4a343eff9e8f"
      file_csi_driver           = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/0d7aedc0-15fd-4a67-a412-efad370c947e"
      image_registry            = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/8b32b316-c2f5-4ddf-b05b-83dacd2d08b5"
      aro_operator              = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/4436bae4-7702-4c84-919b-c4069ff25ee2"
      rp_network_contributor    = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7"
    },
    {
      reader = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
    }
  )
}

# RP SP lookup (fixed appId) - skipped if caller provides the object ID (fixed appId) - skipped if caller provides the object ID
data "azuread_service_principal" "aro_rp" {
  count = var.aro_rp_object_id == null ? 1 : 0

  client_id = "f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875"
}

resource "azurerm_resource_group" "rg" {
  location = local.region
  name     = "aro-example-${random_string.sfx.result}"
}

resource "azurerm_virtual_network" "vnet" {
  location            = azurerm_resource_group.rg.location
  name                = "aro-vnet-${random_string.sfx.result}"
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/23"]
}

# --- Subnets ---
resource "azurerm_subnet" "master" {
  address_prefixes                              = ["10.0.0.0/27"]
  name                                          = "master-subnet"
  resource_group_name                           = azurerm_resource_group.rg.name
  virtual_network_name                          = azurerm_virtual_network.vnet.name
  private_link_service_network_policies_enabled = false
  service_endpoints                             = ["Microsoft.ContainerRegistry", "Microsoft.Storage"]
}

resource "azurerm_subnet" "worker" {
  address_prefixes     = ["10.0.0.128/25"]
  name                 = "worker-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  service_endpoints    = ["Microsoft.ContainerRegistry", "Microsoft.Storage"]
}

# --- NAT Gateway egress (fixed public egress IP) ---
resource "azurerm_public_ip" "nat" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.rg.location
  name                = "aro-natgw-pip-${local.identity_suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "nat" {
  location            = azurerm_resource_group.rg.location
  name                = "aro-natgw-${local.identity_suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "nat" {
  nat_gateway_id       = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "master" {
  nat_gateway_id = azurerm_nat_gateway.nat.id
  subnet_id      = azurerm_subnet.master.id
}

resource "azurerm_subnet_nat_gateway_association" "worker" {
  nat_gateway_id = azurerm_nat_gateway.nat.id
  subnet_id      = azurerm_subnet.worker.id
}

# --- UDR for UserDefinedRouting (default route to Internet; NAT does the SNAT) ---
resource "azurerm_route_table" "udr" {
  location            = azurerm_resource_group.rg.location
  name                = "aro-udr-${local.identity_suffix}"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_route" "default_internet" {
  address_prefix      = "0.0.0.0/0"
  name                = "default-to-internet"
  next_hop_type       = "Internet"
  resource_group_name = azurerm_resource_group.rg.name
  route_table_name    = azurerm_route_table.udr.name
}

resource "azurerm_subnet_route_table_association" "master" {
  route_table_id = azurerm_route_table.udr.id
  subnet_id      = azurerm_subnet.master.id
}

resource "azurerm_subnet_route_table_association" "worker" {
  route_table_id = azurerm_route_table.udr.id
  subnet_id      = azurerm_subnet.worker.id
}

# Required: RP needs Network Contributor on the VNet
resource "azurerm_role_assignment" "rp_vnet_nc" {
  principal_id       = local.rp_object_id
  scope              = azurerm_virtual_network.vnet.id
  role_definition_id = local.role_definition_ids.rp_network_contributor

  lifecycle {
    precondition {
      condition     = local.rp_object_id != null
      error_message = "Unable to determine the Azure Red Hat OpenShift RP object ID. Provide `aro_rp_object_id` when Microsoft Graph lookups are not permitted."
    }
  }
}

resource "azurerm_role_assignment" "rp_route_table_nc" {
  principal_id       = local.rp_object_id
  scope              = azurerm_route_table.udr.id
  role_definition_id = local.role_definition_ids.rp_network_contributor

  lifecycle {
    precondition {
      condition     = local.rp_object_id != null
      error_message = "Unable to determine the Azure Red Hat OpenShift RP object ID. Provide `aro_rp_object_id` when Microsoft Graph lookups are not permitted."
    }
  }
}

resource "azurerm_role_assignment" "rp_nat_gateway_nc" {
  principal_id       = local.rp_object_id
  scope              = azurerm_nat_gateway.nat.id
  role_definition_id = local.role_definition_ids.rp_network_contributor

  lifecycle {
    precondition {
      condition     = local.rp_object_id != null
      error_message = "Unable to determine the Azure Red Hat OpenShift RP object ID. Provide `aro_rp_object_id` when Microsoft Graph lookups are not permitted."
    }
  }
}

locals {
  platform_role_assignments = flatten([
    for identity_key, spec in local.platform_identity_specs : [
      for assignment_index, assignment in spec.assignments : {
        identity_key       = identity_key
        scope_key          = assignment.scope_key
        scope              = local.scope_targets[assignment.scope_key]
        role_definition_id = assignment.role_definition_id
        key                = "${identity_key}-${assignment.scope_key}-${assignment_index}"
      }
    ]
  ])
  scope_targets = {
    master_subnet   = azurerm_subnet.master.id
    worker_subnet   = azurerm_subnet.worker.id
    virtual_network = azurerm_virtual_network.vnet.id
    route_table     = azurerm_route_table.udr.id
    nat_gateway     = azurerm_nat_gateway.nat.id
  }
}

resource "azurerm_user_assigned_identity" "cluster" {
  location            = azurerm_resource_group.rg.location
  name                = local.cluster_identity_name
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_user_assigned_identity" "platform" {
  for_each = local.platform_identity_specs

  location            = azurerm_resource_group.rg.location
  name                = each.value.name
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "cluster_over_platform" {
  for_each = azurerm_user_assigned_identity.platform

  principal_id       = azurerm_user_assigned_identity.cluster.principal_id
  scope              = each.value.id
  principal_type     = "ServicePrincipal"
  role_definition_id = local.role_definition_ids.federated_credential
}

resource "azurerm_role_assignment" "cluster_over_platform_managed_identity_operator" {
  for_each = azurerm_user_assigned_identity.platform

  principal_id       = azurerm_user_assigned_identity.cluster.principal_id
  scope              = each.value.id
  principal_type     = "ServicePrincipal"
  role_definition_id = local.role_definition_ids.managed_identity_operator
}

resource "azurerm_role_assignment" "cluster_subnet_network_contributor" {
  for_each = {
    master = azurerm_subnet.master.id
    worker = azurerm_subnet.worker.id
  }

  principal_id       = azurerm_user_assigned_identity.cluster.principal_id
  scope              = each.value
  principal_type     = "ServicePrincipal"
  role_definition_id = local.role_definition_ids.rp_network_contributor
}

resource "azurerm_role_assignment" "platform_scoped" {
  for_each = { for assignment in local.platform_role_assignments : assignment.key => assignment }

  principal_id       = azurerm_user_assigned_identity.platform[each.value.identity_key].principal_id
  scope              = each.value.scope
  principal_type     = "ServicePrincipal"
  role_definition_id = each.value.role_definition_id
}

# -------------------------
# ARO (via module using AzAPI)
# -------------------------
module "aro_cluster" {
  source = "../../"

  api_server_profile = {
    visibility = "Private" # was Public
  }
  cluster_profile = {
    domain                 = "aro${random_string.sfx.result}"
    version                = "4.14.51"
    pull_secret            = null
    fips_validated_modules = false
    resource_group_id      = local.cluster_resource_group_id
    oidc_issuer            = null
  }
  location = azurerm_resource_group.rg.location
  main_profile = {
    vm_size                    = "Standard_D8s_v5"
    subnet_id                  = azurerm_subnet.master.id
    encryption_at_host_enabled = false
    disk_encryption_set_id     = null
  }
  name = "aro-${random_string.sfx.result}"
  network_profile = {
    pod_cidr                                     = "10.128.0.0/14"
    service_cidr                                 = "172.30.0.0/16"
    outbound_type                                = "UserDefinedRouting" # key change
    preconfigured_network_security_group_enabled = false
  }
  resource_group_name = azurerm_resource_group.rg.name
  worker_profile = {
    vm_size                    = "Standard_D8s_v5"
    node_count                 = 3
    subnet_id                  = azurerm_subnet.worker.id
    disk_size_gb               = 128
    encryption_at_host_enabled = false
    disk_encryption_set_id     = null
  }
  identity_ids = [azurerm_user_assigned_identity.cluster.id]
  ingress_profiles = [
    { name = "default", visibility = "Private" } # was Public
  ]
  platform_workload_identities = {
    for key, identity in azurerm_user_assigned_identity.platform :
    key => identity.id
  }
  tags = { env = "mi-example" }
  timeouts = {
    create = "120m"
    update = "120m"
    delete = "120m"
  }

  depends_on = [
    azapi_resource_action.redhatopenshift_registration,
    # Ensure egress path exists before control plane boots:
    azurerm_nat_gateway_public_ip_association.nat,
    azurerm_subnet_nat_gateway_association.master,
    azurerm_subnet_nat_gateway_association.worker,
    azurerm_subnet_route_table_association.master,
    azurerm_subnet_route_table_association.worker,
    # Identity/RBAC prereqs (include RT permissions):
    azurerm_role_assignment.rp_vnet_nc,
    azurerm_role_assignment.rp_route_table_nc,
    azurerm_role_assignment.rp_nat_gateway_nc,
    azurerm_role_assignment.cluster_over_platform,
    azurerm_role_assignment.cluster_over_platform_managed_identity_operator,
    azurerm_role_assignment.cluster_subnet_network_contributor,
    azurerm_role_assignment.platform_scoped,
  ]
}
