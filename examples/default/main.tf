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
  name     = local.prefixed_rg_name
}

# Create a virtual network for the ARO cluster
resource "azurerm_virtual_network" "this" {
  location            = azurerm_resource_group.this.location
  name                = local.prefixed_vnet_name
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/22"]
}

# Create subnet for master nodes
resource "azurerm_subnet" "master" {
  address_prefixes     = ["10.0.0.0/24"]
  name                 = "${var.name_prefix}-master-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  service_endpoints    = ["Microsoft.ContainerRegistry"]
}

# Create subnet for worker nodes
resource "azurerm_subnet" "worker" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "${var.name_prefix}-worker-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  service_endpoints    = ["Microsoft.ContainerRegistry"]
}

# Clean ARO-dedicated subnets (no NSG, no route table) to satisfy ARO requirements
resource "azurerm_subnet" "aro_master" {
  name                 = "${var.name_prefix}-aro-master"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.ContainerRegistry"]
}

resource "azurerm_subnet" "aro_worker" {
  name                 = "${var.name_prefix}-aro-worker"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.3.0/24"]
  service_endpoints    = ["Microsoft.ContainerRegistry"]
}

# Create service principal for ARO cluster
resource "azuread_application" "aro" {
  display_name = local.prefixed_app_name
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

# ARO Resource Provider service principal (needs Network Contributor on the VNet)
# Using client_id (preferred) instead of deprecated application_id attribute.
data "azuread_service_principal" "aro_rp" {
  client_id = var.rp_application_id
}

resource "azurerm_role_assignment" "aro_rp_network_contributor" {
  count                = var.assign_rp_vnet_role ? 1 : 0
  scope                = azurerm_virtual_network.this.id
  role_definition_name = "Network Contributor"
  principal_id         = data.azuread_service_principal.aro_rp.object_id
}

# Parameterize OpenShift version
variable "openshift_version" {
  type        = string
  description = "Desired Azure Red Hat OpenShift (ARO) version. Must be one returned by 'az aro get-versions --location <region>'."
  default     = "4.17.27" # Latest from centralus at time of update (see az aro get-versions output)
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
    domain  = local.prefixed_domain
    version = var.openshift_version
  }
  # Ingress configuration
  ingress_profile = {
    visibility = "Public"
  }
  # Basic configuration
  location = azurerm_resource_group.this.location
  # Master node configuration
  main_profile = {
    subnet_id = azurerm_subnet.aro_master.id
    vm_size   = "Standard_D8s_v3"
  }
  name = local.prefixed_cluster_name
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
    subnet_id    = azurerm_subnet.aro_worker.id
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
    azurerm_role_assignment.aro_contributor,
    null_resource.register_redhatopenshift,
    azurerm_role_assignment.aro_rp_network_contributor
  ]
}

# Attempt to register the Microsoft.RedHatOpenShift resource provider if requested.
resource "null_resource" "register_redhatopenshift" {
  count = var.auto_register_redhatopenshift ? 1 : 0

  triggers = {
    target_version = var.openshift_version
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    # NOTE: The provisioner script uses $${...} to avoid Terraform interpolation in the heredoc.
    command = <<EOT
set -euo pipefail
NS=Microsoft.RedHatOpenShift
log() { echo "[rp-register] $*"; }
if ! command -v az >/dev/null 2>&1; then
  log "az CLI not found; skipping automatic RP registration" >&2
  exit 0
fi
state=$(az provider show --namespace "$NS" --query registrationState -o tsv 2>/dev/null || echo NotRegistered)
if [ "$state" = Registered ]; then
  log "Resource provider already registered"
  exit 0
fi
log "Current state: $state. Initiating registration..."
# Use --wait if available (CLI supports it) to block until completion
if az provider register --namespace "$NS" --wait >/dev/null 2>&1; then
  log "Registration completed via --wait"
  exit 0
else
  log "--wait not supported or failed; falling back to manual polling"
  az provider register --namespace "$NS" || true
fi
# Manual polling with exponential backoff up to ~15 minutes
max_minutes=15
elapsed=0
sleep_seconds=5
while [ $elapsed -lt $((max_minutes*60)) ]; do
  state=$(az provider show --namespace "$NS" --query registrationState -o tsv 2>/dev/null || echo NotRegistered)
  log "State: $state (elapsed $${elapsed}s)"
  if [ "$state" = Registered ]; then
    log "Successfully registered $NS"
    exit 0
  fi
  sleep $sleep_seconds
  elapsed=$((elapsed + sleep_seconds))
  # Increase wait gradually up to 60s
  if [ $sleep_seconds -lt 60 ]; then
    sleep_seconds=$((sleep_seconds * 2))
    [ $sleep_seconds -gt 60 ] && sleep_seconds=60
  fi
done
log "Timed out after $${max_minutes}m waiting for $NS registration" >&2
exit 2
EOT
  }
}

variable "auto_register_redhatopenshift" {
  type        = bool
  default     = true
  description = "If true, attempt to register the Microsoft.RedHatOpenShift resource provider using az CLI before creating the cluster. Requires az CLI and subscription-level permissions."
}

variable "name_prefix" {
  type        = string
  description = "Prefix applied to all created resource names for identification. Must meet Azure naming constraints where applicable."
  default     = "aro"
}

variable "assign_rp_vnet_role" {
  type        = bool
  description = "If true, assign Network Contributor on the cluster VNet to the ARO resource provider service principal (rp_application_id)."
  default     = true
}

variable "rp_application_id" {
  type        = string
  description = "Application (client) ID of the Azure Red Hat OpenShift resource provider service principal. Override if it changes in sovereign clouds or sandbox environments."
  # Public (commercial) ARO RP application ID observed from error; can be overridden.
  default = "f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875"
}

# Helper locals to consistently apply prefix
locals {
  prefixed_rg_name      = "${var.name_prefix}-${module.naming.resource_group.name_unique}"
  prefixed_vnet_name    = "${var.name_prefix}-${module.naming.virtual_network.name_unique}"
  prefixed_app_name     = "${var.name_prefix}-${module.naming.unique-seed}"
  prefixed_cluster_seg  = substr(module.naming.unique-seed, 0, 8)
  prefixed_cluster_name = "${var.name_prefix}-${local.prefixed_cluster_seg}" # for display
  prefixed_domain       = "${var.name_prefix}${local.prefixed_cluster_seg}"  # domain cannot contain '-'
}
