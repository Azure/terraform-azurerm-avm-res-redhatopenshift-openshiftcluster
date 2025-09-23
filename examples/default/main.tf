terraform {
  required_version = "~> 1.5"

  required_providers {
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
  resource_provider_registrations = "none"
}

# Register required resource providers for ARO deployment
# Only register Microsoft.RedHatOpenShift as other providers are auto-registered by azurerm
# NOTE: Commented out once registered
# resource "azurerm_resource_provider_registration" "redhatopenshift" {
#   name = "Microsoft.RedHatOpenShift"
# }

locals {
  deployment_region = "westus"
  # Add timestamp to ensure uniqueness across runs
  timestamp = formatdate("MMDDhhmm", timestamp())
}

resource "random_string" "suffix" {
  length = 6
  # Add keepers to force new random string on each run
  keepers = {
    timestamp = local.timestamp
  }
  special = false
  upper   = false
}

resource "azurerm_resource_group" "this" {
  location = local.deployment_region
  name     = "aro-test-${local.timestamp}-${random_string.suffix.result}"
}

resource "azurerm_virtual_network" "this" {
  location            = azurerm_resource_group.this.location
  name                = "aro-vnet-${local.timestamp}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/23"] # Match portal template: smaller address space
}

resource "azurerm_subnet" "main_subnet" {
  address_prefixes                              = ["10.0.0.0/27"]
  name                                          = "master-subnet"
  resource_group_name                           = azurerm_resource_group.this.name
  virtual_network_name                          = azurerm_virtual_network.this.name
  private_link_service_network_policies_enabled = false
  service_endpoints                             = ["Microsoft.ContainerRegistry"]
}

resource "azurerm_subnet" "worker_subnet" {
  address_prefixes     = ["10.0.0.128/25"]
  name                 = "worker-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  service_endpoints    = ["Microsoft.ContainerRegistry"]
}

# Service principal for ARO cluster - must be provided via variables
# In CI/CD environments, create the service principal externally and pass the values
# Example: terraform apply -var="service_principal_client_id=<your-client-id>" -var="service_principal_client_secret=<your-secret>"

# Optional role assignment for ARO service principal on VNet
# Only created if service_principal_object_id is provided
resource "azurerm_role_assignment" "role_network1" {
  count = var.service_principal_object_id != null ? 1 : 0

  principal_id         = var.service_principal_object_id
  scope                = azurerm_virtual_network.this.id
  role_definition_name = "Network Contributor"
}

module "aro_cluster" {
  source = "../../"

  api_server_profile = {
    visibility = "Public"
  }
  cluster_profile = {
    domain                      = "aro${local.timestamp}${random_string.suffix.result}"
    version                     = "4.14.51"
    fips_enabled                = false
    managed_resource_group_name = null
    pull_secret                 = null
  }
  ingress_profile = {
    visibility = "Public"
  }
  location = azurerm_resource_group.this.location
  main_profile = {
    vm_size                    = "Standard_D8s_v3"
    subnet_id                  = azurerm_subnet.main_subnet.id
    disk_encryption_set_id     = null
    encryption_at_host_enabled = false
  }
  name = "aro-cluster-${local.timestamp}-${random_string.suffix.result}"
  network_profile = {
    pod_cidr     = "10.128.0.0/14"
    service_cidr = "172.30.0.0/16"
  }
  resource_group_name = azurerm_resource_group.this.name
  worker_profile = {
    vm_size                    = "Standard_D4s_v3"
    disk_size_gb               = 128
    node_count                 = 3
    subnet_id                  = azurerm_subnet.worker_subnet.id
    disk_encryption_set_id     = null
    encryption_at_host_enabled = false
  }
  enable_telemetry = var.enable_telemetry
  # service_principal is optional - if not provided, ARO will auto-create one
  service_principal = var.service_principal_client_id != null && var.service_principal_client_secret != null ? {
    client_id     = var.service_principal_client_id
    client_secret = var.service_principal_client_secret
  } : null
  timeouts = {
    create = "120m"
    delete = "120m"
    update = "120m"
  }

  depends_on = [
    azurerm_role_assignment.role_network1,
  ]
}

