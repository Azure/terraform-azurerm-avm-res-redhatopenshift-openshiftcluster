terraform {
  required_version = "~> 1.5"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.15"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azuread" {}

data "azurerm_client_config" "current" {}

variable "aro_rp_client_id" {
  description = "Azure Red Hat OpenShift resource provider service principal client ID"
  type        = string
  default     = "f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875"
}

data "azuread_service_principal" "aro_rp" {
  # Azure Red Hat OpenShift resource provider service principal
  client_id = var.aro_rp_client_id
}

## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/regions/azurerm"
  version = "0.8.2"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  max = length(local.allowed_regions) - 1
  min = 0
}

# Filter regions to only those that support ARO
locals {
  allowed_regions = [
    for region in module.regions.regions :
    region if contains([
      "East US",
      "East US 2",
      "West US 2",
      "Central US",
      "West Europe",
      "North Europe",
      "UK South",
      "France Central",
      "Australia East",
      "Southeast Asia"
    ], region.display_name)
  ]
  platform_identity_names = [
    "aro-operator",
    "cloud-controller-manager",
    "cloud-network-config",
    "disk-csi-driver",
    "file-csi-driver",
    "image-registry",
    "ingress",
    "machine-api"
  ]
  platform_network_role_bindings = {
    "aro-operator" = {
      role_definition_name = "Azure Red Hat OpenShift Service Operator"
      scopes = {
        master = azurerm_subnet.master.id
        worker = azurerm_subnet.worker.id
      }
    }
    "cloud-controller-manager" = {
      role_definition_name = "Azure Red Hat OpenShift Cloud Controller Manager"
      scopes = {
        master = azurerm_subnet.master.id
        worker = azurerm_subnet.worker.id
      }
    }
    "cloud-network-config" = {
      role_definition_name = "Azure Red Hat OpenShift Network Operator"
      scopes = {
        vnet = azurerm_virtual_network.this.id
      }
    }
    "file-csi-driver" = {
      role_definition_name = "Azure Red Hat OpenShift File Storage Operator"
      scopes = {
        vnet = azurerm_virtual_network.this.id
      }
    }
    "image-registry" = {
      role_definition_name = "Azure Red Hat OpenShift Image Registry Operator"
      scopes = {
        vnet = azurerm_virtual_network.this.id
      }
    }
    "ingress" = {
      role_definition_name = "Azure Red Hat OpenShift Cluster Ingress Operator"
      scopes = {
        master = azurerm_subnet.master.id
        worker = azurerm_subnet.worker.id
      }
    }
    "machine-api" = {
      role_definition_name = "Azure Red Hat OpenShift Machine API Operator"
      scopes = {
        master = azurerm_subnet.master.id
        worker = azurerm_subnet.worker.id
      }
    }
  }
}
## End of section to provide a random Azure region for the resource group

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"
}

# Short seed + derived ARO identifiers to satisfy name length validation
locals {
  aro_cluster_domain = "aro${local.aro_seed_short}"
  aro_cluster_name   = "aro-${local.aro_seed_short}"
  aro_seed_raw       = module.naming.resource_group.name_unique
  aro_seed_short     = substr(replace(local.aro_seed_raw, "rg-", ""), 0, 12)
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = local.allowed_regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

# Create a virtual network for the ARO cluster
resource "azurerm_virtual_network" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/22"]
}

# Create subnet for master nodes
resource "azurerm_subnet" "master" {
  address_prefixes                              = ["10.0.0.0/23"]
  name                                          = "master-subnet"
  resource_group_name                           = azurerm_resource_group.this.name
  virtual_network_name                          = azurerm_virtual_network.this.name
  private_link_service_network_policies_enabled = false
  service_endpoints                             = ["Microsoft.Storage", "Microsoft.ContainerRegistry"]
}

# Create subnet for worker nodes
resource "azurerm_subnet" "worker" {
  address_prefixes                              = ["10.0.2.0/24"]
  name                                          = "worker-subnet"
  resource_group_name                           = azurerm_resource_group.this.name
  virtual_network_name                          = azurerm_virtual_network.this.name
  private_link_service_network_policies_enabled = false
  service_endpoints                             = ["Microsoft.Storage", "Microsoft.ContainerRegistry"]
}

resource "azurerm_user_assigned_identity" "cluster" {
  location            = azurerm_resource_group.this.location
  name                = "aro-cluster"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_user_assigned_identity" "platform" {
  for_each = toset(local.platform_identity_names)

  location            = azurerm_resource_group.this.location
  name                = each.value
  resource_group_name = azurerm_resource_group.this.name
}

# The cluster identity must be able to issue federated credentials for each operator identity
resource "azurerm_role_assignment" "cluster_over_platform" {
  for_each = azurerm_user_assigned_identity.platform

  principal_id                     = azurerm_user_assigned_identity.cluster.principal_id
  scope                            = each.value.id
  principal_type                   = "ServicePrincipal"
  role_definition_name             = "Azure Red Hat OpenShift Federated Credential"
  skip_service_principal_aad_check = true
}

# Grant each operator identity the minimum role on the required network scope
resource "azurerm_role_assignment" "platform_network" {
  for_each = {
    for binding in flatten([
      for identity_key, value in local.platform_network_role_bindings : [
        for scope_key, scope_id in value.scopes : {
          identity_key         = identity_key
          scope_key            = scope_key
          role_definition_name = value.role_definition_name
          scope                = scope_id
          key                  = format("%s-%s", identity_key, scope_key)
        }
      ]
    ]) : binding.key => binding
  }

  principal_id                     = azurerm_user_assigned_identity.platform[each.value.identity_key].principal_id
  scope                            = each.value.scope
  principal_type                   = "ServicePrincipal"
  role_definition_name             = each.value.role_definition_name
  skip_service_principal_aad_check = true
}

# Ensure the Azure Red Hat OpenShift RP retains access to the network
resource "azurerm_role_assignment" "rp_network_contributor" {
  principal_id                     = data.azuread_service_principal.aro_rp.object_id
  scope                            = azurerm_virtual_network.this.id
  principal_type                   = "ServicePrincipal"
  role_definition_name             = "Network Contributor"
  skip_service_principal_aad_check = true
}

# This is the module call
module "aro_cluster" {
  source = "../../"

  api_server_profile = {
    visibility = "Public"
  }
  cluster_profile = {
    domain  = local.aro_cluster_domain
    version = "4.16.39"
  }
  ingress_profile = {
    visibility = "Public"
  }
  location = azurerm_resource_group.this.location
  main_profile = {
    subnet_id = azurerm_subnet.master.id
    vm_size   = "Standard_D8s_v3"
  }
  name = local.aro_cluster_name
  network_profile = {
    pod_cidr     = "10.128.0.0/14"
    service_cidr = "172.30.0.0/16"
  }
  resource_group_name = azurerm_resource_group.this.name
  worker_profile = {
    subnet_id    = azurerm_subnet.worker.id
    vm_size      = "Standard_D4s_v3"
    node_count   = 3
    disk_size_gb = 128
  }
  enable_telemetry = var.enable_telemetry
  managed_identities = {
    user_assigned_resource_ids = toset([
      azurerm_user_assigned_identity.cluster.id
    ])
  }
  platform_workload_identities = {
    for name, identity in azurerm_user_assigned_identity.platform : name => {
      resource_id = identity.id
    }
  }
  timeouts = {
    create = "120m"
    delete = "120m"
    update = "120m"
  }

  depends_on = [
    azurerm_role_assignment.cluster_over_platform,
    azurerm_role_assignment.platform_network,
    azurerm_role_assignment.rp_network_contributor,
  ]
}
