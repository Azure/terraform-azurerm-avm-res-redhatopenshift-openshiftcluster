# terraform-azurerm-avm-res-redhatopenshift-openshiftcluster

This is an Azure Verified Module for deploying Azure Red Hat OpenShift (ARO) clusters.

## Features

- **Complete ARO cluster deployment** with all configuration options
- **AVM compliance** with standard interfaces for role assignments, diagnostic settings, and resource locks
- **Private networking support** via API server and ingress visibility controls
- **Flexible node configuration** for both master and worker nodes
- **Security best practices** with service principal authentication and encryption options
- **Comprehensive validation** for network configuration and cluster parameters

## Requirements

Before deploying an ARO cluster, ensure you have:

1. **Service Principal**: A service principal with appropriate permissions
2. **Virtual Network**: Pre-configured virtual network with subnets for master and worker nodes
3. **Red Hat Account**: Optional pull secret for accessing Red Hat container registries
4. **Resource Quotas**: Sufficient Azure resource quotas for the cluster size

> [!IMPORTANT]
> Azure Red Hat OpenShift clusters require significant compute and networking resources. Ensure your subscription has adequate quotas before deployment.

> [!NOTE]  
> This module deploys Azure Red Hat OpenShift v4.11+ which requires specific network and resource configurations. Review the Azure Red Hat OpenShift documentation for detailed prerequisites.
