# Azure Red Hat OpenShift cluster

Deploys an Azure Red Hat OpenShift cluster with service principal or managed identity authentication.

## Upgrade considerations

The module requires Terraform 1.9 or later and AzureRM 4.x. Existing cluster, private endpoint, application security group association, and cluster role assignment addresses are unchanged. Optional endpoint role assignments and locks, previously ignored, now create AzAPI extension resources. Review the added permissions and locks before applying an upgrade.

Private endpoint `subresource_name` and IP configuration `member_name` are honored; omitting them retains the existing `cluster` fallback. Confirm the group and member names supported by your target service before configuring an endpoint. API server and ingress visibility are configured independently through their profiles.

When `private_endpoints_manage_dns_zone_group = false`, only the unmanaged endpoint address is created. Earlier versions also created the managed address for the same endpoint. For each affected map key, the two addresses within this module are `azurerm_private_endpoint.this_managed_dns_zone_groups["<key>"]` and `azurerm_private_endpoint.this_unmanaged_dns_zone_groups["<key>"]`; include your actual module path when inspecting state.

If both addresses are already in state, **do not apply a plan that deletes either copy**: they may represent the same Azure endpoint. Take a secure state backup, verify that both resource IDs identify the **same** endpoint, confirm that the unmanaged address is the intended owner, and have the state owner remove only the duplicate managed binding from Terraform state while retaining the unmanaged binding and Azure resource. If the IDs differ, investigate both resources rather than removing either automatically. Review the resulting plan and stop on any unexpected endpoint deletion or recreation. This is a breaking upgrade for affected configurations; the module does not read or reconcile existing state.

> [!IMPORTANT]
> As the overall AVM framework is not GA (generally available) yet - the CI framework and test automation is not fully functional and implemented across all supported languages yet - breaking changes are expected, and additional customer feedback is yet to be gathered and incorporated. Hence, modules **MUST NOT** be published at version `1.0.0` or higher at this time.
> 
> All module **MUST** be published as a pre-release version (e.g., `0.1.0`, `0.1.1`, `0.2.0`, etc.) until the AVM framework becomes GA.
> 
> However, it is important to note that this **DOES NOT** mean that the modules cannot be consumed and utilized. They **CAN** be leveraged in all types of environments (dev, test, prod etc.). Consumers can treat them just like any other IaC module and raise issues or feature requests against them as they learn from the usage of the module. Consumers should also read the release notes for each version, if considering updating to a more recent version of a module to see if there are any considerations or breaking changes etc.
