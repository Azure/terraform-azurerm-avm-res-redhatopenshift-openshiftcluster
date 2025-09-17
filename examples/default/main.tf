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

locals {
  deployment_region = "westus"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

data "azurerm_client_config" "current" {}
# data "azuread_client_config" "current" {}  # Unused data source

resource "azurerm_resource_group" "this" {
  location = local.deployment_region
  name     = "aro-rg-${random_string.suffix.result}"
}

resource "azurerm_virtual_network" "this" {
  location            = azurerm_resource_group.this.location
  name                = "aro-vnet-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/23"] # Match portal template: smaller address space
}

resource "azurerm_subnet" "main_subnet" {
  address_prefixes                              = ["10.0.0.0/27"] # Match portal: master subnet
  name                                          = "master-subnet" # Match portal naming
  resource_group_name                           = azurerm_resource_group.this.name
  virtual_network_name                          = azurerm_virtual_network.this.name
  private_link_service_network_policies_enabled = false # Match portal: disabled for master
  service_endpoints                             = ["Microsoft.ContainerRegistry"]
}

resource "azurerm_subnet" "worker_subnet" {
  address_prefixes     = ["10.0.0.128/25"] # Match portal: worker subnet
  name                 = "worker-subnet"   # Match portal naming
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  service_endpoints    = ["Microsoft.ContainerRegistry"]
}

resource "azuread_application" "aro" {
  display_name = "aro-app-${random_string.suffix.result}"
}

resource "azuread_service_principal" "aro" {
  client_id = azuread_application.aro.client_id
}

resource "azuread_service_principal_password" "aro" {
  service_principal_id = azuread_service_principal.aro.object_id
}

data "azuread_service_principal" "redhatopenshift" {
  client_id = "f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875"
}

resource "azurerm_role_assignment" "role_network1" {
  principal_id       = azuread_service_principal.aro.object_id
  scope              = azurerm_virtual_network.this.id
  role_definition_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7" # Network Contributor exact ID from portal
}

resource "azurerm_role_assignment" "role_network2" {
  principal_id       = data.azuread_service_principal.redhatopenshift.object_id
  scope              = azurerm_virtual_network.this.id
  role_definition_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7" # Network Contributor exact ID from portal
}

module "aro_cluster" {
  source = "../../"

  api_server_profile = {
    visibility = "Public"
  }
  cluster_profile = {
    domain                      = "aro${random_string.suffix.result}"
    version                     = "4.14.16" # Use a known stable version
    fips_enabled                = false     # Match portal template
    managed_resource_group_name = null      # Let Azure generate
    pull_secret                 = null      # Will fail without real pull secret but let's see other issues first
  }
  ingress_profile = {
    visibility = "Public"
  }
  location = azurerm_resource_group.this.location
  main_profile = {
    vm_size                    = "Standard_D8s_v3"
    subnet_id                  = azurerm_subnet.main_subnet.id
    disk_encryption_set_id     = null
    encryption_at_host_enabled = false # Match portal template
  }
  name = "aro-cluster-${random_string.suffix.result}"
  network_profile = {
    pod_cidr     = "10.128.0.0/14"
    service_cidr = "172.30.0.0/16"
  }
  resource_group_name = azurerm_resource_group.this.name
  service_principal = {
    client_id     = azuread_application.aro.client_id
    client_secret = azuread_service_principal_password.aro.value
  }
  worker_profile = {
    vm_size                    = "Standard_D4s_v3"
    disk_size_gb               = 128
    node_count                 = 3
    subnet_id                  = azurerm_subnet.worker_subnet.id
    disk_encryption_set_id     = null
    encryption_at_host_enabled = false # Match portal template
  }
  enable_telemetry = var.enable_telemetry
  timeouts = {
    create = "120m"
    delete = "120m"
    update = "120m"
  }

  depends_on = [
    azurerm_role_assignment.role_network1,
    azurerm_role_assignment.role_network2,
  ]
}

