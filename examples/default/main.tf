terraform {
  required_version = "~> 1.5"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
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

# Create Azure AD application for ARO cluster
resource "azuread_application" "aro_cluster" {
  count = var.cluster_service_principal == null ? 1 : 0

  display_name = "aro-cluster-${local.timestamp}-${random_string.suffix.result}"
}

# Create service principal for the application
resource "azuread_service_principal" "aro_cluster" {
  count = var.cluster_service_principal == null ? 1 : 0

  client_id = azuread_application.aro_cluster[0].client_id
}

# Create password for the service principal
resource "azuread_service_principal_password" "aro_cluster" {
  count = var.cluster_service_principal == null ? 1 : 0

  service_principal_id = azuread_service_principal.aro_cluster[0].object_id
}

# Get the Azure Red Hat OpenShift resource provider service principal
data "azuread_service_principal" "redhatopenshift" {
  count = var.aro_rp_object_id == null ? 1 : 0

  # This is the Azure Red Hat OpenShift RP service principal id, do NOT delete it
  client_id = "f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875"
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

locals {
  aro_rp_object_id         = var.aro_rp_object_id != null ? var.aro_rp_object_id : try(data.azuread_service_principal.redhatopenshift[0].object_id, null)
  cluster_sp_client_id     = var.cluster_service_principal == null ? azuread_application.aro_cluster[0].client_id : var.cluster_service_principal.client_id
  cluster_sp_client_secret = var.cluster_service_principal == null ? azuread_service_principal_password.aro_cluster[0].value : var.cluster_service_principal.client_secret
  cluster_sp_object_id     = var.cluster_service_principal == null ? azuread_service_principal.aro_cluster[0].object_id : var.cluster_service_principal.object_id
}

# Role assignment for ARO cluster service principal on VNet
resource "azurerm_role_assignment" "role_network_cluster_sp" {
  principal_id         = local.cluster_sp_object_id
  scope                = azurerm_virtual_network.this.id
  role_definition_name = "Network Contributor"
}

# Role assignment for ARO Resource Provider service principal on VNet
resource "azurerm_role_assignment" "role_network_aro_rp" {
  principal_id         = local.aro_rp_object_id
  scope                = azurerm_virtual_network.this.id
  role_definition_name = "Network Contributor"

  lifecycle {
    precondition {
      condition     = local.aro_rp_object_id != null
      error_message = "Unable to determine Azure Red Hat OpenShift RP object ID. Set `aro_rp_object_id` when Microsoft Graph lookup is not permitted."
    }
  }
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
  # Use the created service principal
  service_principal = {
    client_id     = local.cluster_sp_client_id
    client_secret = local.cluster_sp_client_secret
  }
  timeouts = {
    create = "120m"
    delete = "120m"
    update = "120m"
  }

  depends_on = [
    azurerm_role_assignment.role_network_cluster_sp,
    azurerm_role_assignment.role_network_aro_rp,
  ]
}
