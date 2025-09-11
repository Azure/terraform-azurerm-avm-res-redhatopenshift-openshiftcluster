# Azure Verified Module for Azure Data Protection Backup Vault

This module provides a generic way to create and manage an Azure Data Protection Backup Vault resource.

To use this module in your Terraform configuration, you'll need to provide values for the required variables.

## Features

- Deploys an Azure Data Protection Backup Vault with support for private endpoints, diagnostic settings, managed identities, resource locks, and role assignments.
- Supports AVM telemetry and tagging.
- Flexible configuration for private DNS zone group management.

## Example Usage

Here is an example of how you can use this module in your Terraform configuration:

```terraform
module "backup_vault" {
  source              = "Azure/avm-res-dataprotection-backupvault/azurerm"
  name                = "my-backupvault"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  enable_telemetry = true

  # Optional: configure private endpoints, diagnostic settings, managed identities, etc.
  # private_endpoints = { ... }
  # diagnostic_settings = { ... }
  # managed_identities = { ... }
  # tags = { environment = "production" }
}
```

## AVM Versioning Notice

Major version Zero (0.y.z) is for initial development. Anything MAY change at any time. The module SHOULD NOT be considered stable till at least it is major version one (1.0.0) or greater. Changes will always be via new versions being published and no changes will be made to existing published versions. For more details please go to <https://semver.org/>
