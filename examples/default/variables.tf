variable "aro_rp_object_id" {
  type        = string
  default     = null
  description = <<DESCRIPTION
Optional object ID for the Azure Red Hat OpenShift resource provider service principal.
Set this when your pipeline lacks permission to query Microsoft Graph for the RP service principal.
If omitted, the example attempts to discover the object ID via the AzureAD provider.
DESCRIPTION
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

variable "location" {
  type        = string
  default     = "eastus"
  description = <<DESCRIPTION
Azure region to deploy the example resources into. Choose a region with sufficient Azure Red Hat OpenShift capacity.

ARO is available in the following regions:
- eastus (East US)
- eastus2 (East US 2)
- centralus (Central US)
- westus2 (West US 2)
- westus3 (West US 3)
- southcentralus (South Central US)
- northeurope (North Europe)
- westeurope (West Europe)
- francecentral (France Central)
- uksouth (UK South)
- australiaeast (Australia East)
- southeastasia (Southeast Asia)
- eastasia (East Asia)
- japaneast (Japan East)
- canadacentral (Canada Central)
- switzerlandnorth (Switzerland North)
- germanywestcentral (Germany West Central)
- swedencentral (Sweden Central)
- norwayeast (Norway East)

Note: Region availability may change over time. Verify current availability at:
https://docs.microsoft.com/en-us/azure/openshift/supported-resources
DESCRIPTION

  validation {
    condition = contains([
      "eastus", "eastus2", "centralus", "westus2", "westus3", "southcentralus",
      "northeurope", "westeurope", "francecentral", "uksouth",
      "australiaeast", "southeastasia", "eastasia", "japaneast",
      "canadacentral", "switzerlandnorth", "germanywestcentral",
      "swedencentral", "norwayeast"
    ], var.location)
    error_message = "The specified location is not supported by Azure Red Hat OpenShift. Please choose from the supported regions list."
  }
}
