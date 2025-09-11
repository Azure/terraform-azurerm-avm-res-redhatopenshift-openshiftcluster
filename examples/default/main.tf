terraform {
  required_version = "~> 1.5"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.15"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.74"
    }
    modtm = {
      source  = "azure/modtm"
      version = "~> 0.3"
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

## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/regions/azurerm"
  version = "~> 0.3"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  max = length(local.allowed_regions) - 1
  min = 0
}

# Filter regions to only those that support ARO
locals {
  # ARO is available in these regions as of 2024
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
}
## End of section to provide a random Azure region for the resource group

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.3"
}

# Current user/service principal data
data "azurerm_client_config" "current" {}

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
  address_prefixes     = ["10.0.0.0/24"]
  name                 = "master-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  service_endpoints = [
    "Microsoft.ContainerRegistry"
  ]
}

# Create subnet for worker nodes  
resource "azurerm_subnet" "worker" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "worker-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  service_endpoints = [
    "Microsoft.ContainerRegistry"
  ]
}

# Create service principal for ARO cluster
resource "azuread_application" "aro" {
  display_name = "aro-${module.naming.unique-seed}"
}

resource "azuread_service_principal" "aro" {
  client_id = azuread_application.aro.client_id
}

resource "azuread_service_principal_password" "aro" {
  service_principal_id = azuread_service_principal.aro.object_id
}

# Assign required permissions to the service principal
resource "azurerm_role_assignment" "aro_contributor" {
  principal_id         = azuread_service_principal.aro.object_id
  scope                = azurerm_virtual_network.this.id
  role_definition_name = "Contributor"
}

# This is the module call
module "aro_cluster" {
  source = "../../"

  # API server configuration
  api_server_profile = {
    visibility = "Public"
  }
  # Cluster configuration
  cluster_profile = {
    domain  = "aro${module.naming.unique-seed}"
    version = "4.11.0" # Use appropriate ARO version
  }
  # Ingress configuration
  ingress_profile = {
    visibility = "Public"
  }
  # Basic configuration
  location = azurerm_resource_group.this.location
  # Master node configuration
  main_profile = {
    subnet_id = azurerm_subnet.master.id
    vm_size   = "Standard_D8s_v3"
  }
  name = "aro-${module.naming.unique-seed}"
  # Network configuration
  network_profile = {
    pod_cidr     = "10.128.0.0/14"
    service_cidr = "172.30.0.0/16"
  }
  resource_group_name = azurerm_resource_group.this.name
  # Service principal configuration
  service_principal = {
    client_id     = azuread_application.aro.client_id
    client_secret = azuread_service_principal_password.aro.value
  }
  # Worker node configuration
  worker_profile = {
    subnet_id    = azurerm_subnet.worker.id
    vm_size      = "Standard_D4s_v3"
    node_count   = 3
    disk_size_gb = 128
  }
  enable_telemetry = var.enable_telemetry
  # Timeouts
  timeouts = {
    create = "120m"
    delete = "120m"
    update = "120m"
  }

  depends_on = [
    azurerm_role_assignment.aro_contributor
  ]
}
