# Azure Verified Modules (AVM) - Red Hat OpenShift Cluster

## Module Architecture

This is an AVM Terraform resource module template for Red Hat OpenShift clusters currently in development. Key files:

- `main.tf` - Primary resource definitions (currently template with TODOs)
- `main.telemetry.tf` - AVM telemetry collection logic 
- `main.privateendpoint.tf` - Private endpoint patterns with managed/unmanaged DNS zones
- `variables.tf` - Complete AVM interface with validation rules
- `locals.tf` - Identity management and PE association logic
- `terraform.tf` - Provider requirements (azurerm ~> 3.71, azapi ~> 2.4, modtm ~> 0.3)

## Critical AVM Patterns

### Template Status
This module is a **template** with placeholder `azurerm_resource_group.TODO` resources. The actual OpenShift cluster resource needs to be implemented to replace all TODO references.

### Required Validation Workflow
**MANDATORY before any PR**: Run these commands to prevent CI failures:
```bash
export PORCH_NO_TUI=1
./avm pre-commit
git add . && git commit -m "chore: avm pre-commit"
./avm pr-check
```

### AVM Interface Requirements
All AVM modules must implement these standardized interfaces:
- `enable_telemetry` (default: true) - Microsoft usage analytics
- `lock` - Resource locking with CanNotDelete/ReadOnly
- `role_assignments` - RBAC with principal_id and role_definition_id_or_name  
- `private_endpoints` - Private connectivity with DNS zone management
- `managed_identities` - System/User assigned identity support
- `diagnostic_settings` - Monitoring and logging configuration
- `customer_managed_key` - CMK encryption support

### Private Endpoint Pattern
Uses dual resource approach:
- `azurerm_private_endpoint.this_managed_dns_zone_groups` - When module manages DNS zones
- `azurerm_private_endpoint.this_unmanaged_dns_zone_groups` - For Azure Policy-managed DNS zones
- Toggle via `private_endpoints_manage_dns_zone_group` variable

### Telemetry Architecture
- Uses `modtm` provider for module source tracking
- Detects forks vs official Azure modules via regex patterns
- Headers added to azapi calls when telemetry enabled
- Requires `data.azapi_client_config.telemetry` for subscription/tenant context

## Development Workflow

### Container-based Development
The `./avm` script provides containerized development environment:
- Uses `mcr.microsoft.com/azterraform:avm-latest` image
- Mounts Azure config, Docker socket, and source code
- Set `PORCH_NO_TUI=1` for non-interactive CI execution

### Examples Structure
`examples/default/` demonstrates:
- Random region selection via `Azure/regions/azurerm` module
- CAF-compliant naming via `Azure/naming/azurerm` module
- Resource group creation pattern
- Module source reference (`source = "../../"`)

### Variable Validation Patterns
- Complex nested object types with optional fields
- Validation rules using `can(regex())` for naming constraints
- Multi-destination diagnostic settings validation
- Lock type enumeration validation

## Implementation Notes

### TODO Replacement Strategy
Replace all placeholder references:
1. `azurerm_resource_group.TODO` → actual OpenShift cluster resource
2. Update `subresource_names` in private endpoints
3. Complete validation rules in `variables.tf`
4. Update resource output in `outputs.tf`

### Locals Pattern
`locals.tf` contains reusable logic for:
- Managed identity type resolution (System/User/Both)
- Private endpoint application security group associations flattening
- Role definition ID detection via substring matching

### Provider Dependencies
- `azurerm` for core Azure resources
- `azapi` for newer Azure features and telemetry client config  
- `modtm` for module telemetry and source detection
- `random` for UUID generation in telemetry

When implementing the actual OpenShift cluster resource, ensure all AVM interfaces are properly connected and remove template TODOs systematically.