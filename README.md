# Terraform Talos Cluster

Terraform/OpenTofu module to bootstrap a [Talos Linux](https://www.talos.dev/) Kubernetes cluster from a list of pre-provisioned nodes.

![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.11.0-blue)
![Talos Provider](https://img.shields.io/badge/talos--provider-0.9.0-purple)

## Features

- Automated Talos cluster bootstrapping from existing nodes
- Support for multiple control plane and worker nodes
- Optional high availability with Virtual IP (VIP) for control plane
- Flexible networking: disable default CNI (Flannel) or kube-proxy for external solutions
- Integrated metrics server and certificate rotation support
- Secure credential management with optional local file output
- Health validation with configurable timeouts

## Prerequisites

Before using this module, ensure you have:

- **Terraform/OpenTofu** >= 1.11.0 installed
- **Pre-provisioned nodes** with Talos Linux installed
- **Static IP addresses** assigned to all nodes
- **Network connectivity** between all cluster nodes

## Architecture

```
talos_machine_secrets
        |
        v
+-------+-------+
|               |
v               v
talos_client    talos_machine
_configuration  _configuration (per node)
                        |
                        v
                talos_machine_configuration_apply (per node)
                        |
                        v
                talos_machine_bootstrap (first control plane)
                        |
                        v
                talos_cluster_health (validates cluster)
                        |
                        v
                talos_cluster_kubeconfig
                        |
                        v
                local_file (optional: kubeconfig, talosconfig)
```

## Usage

### Basic Example

```hcl
module "talos_cluster" {
  source = "path/to/terraform-talos-cluster"

  cluster_name       = "my-cluster"
  kubernetes_version = "v1.33.3"
  talos_version      = "v1.10.6"

  talos_nodes = {
    cp1 = {
      ip_address   = "10.0.1.10"
      ip_subnet    = 24
      machine_type = "controlplane"
    }
    worker1 = {
      ip_address   = "10.0.1.20"
      ip_subnet    = 24
      machine_type = "worker"
    }
  }
}

output "kubeconfig" {
  value     = module.talos_cluster.kubeconfig
  sensitive = true
}
```

### High Availability with VIP

```hcl
module "talos_cluster" {
  source = "path/to/terraform-talos-cluster"

  cluster_name       = "ha-cluster"
  cluster_vip        = "10.0.1.5"  # Virtual IP for control plane HA
  kubernetes_version = "v1.33.3"
  talos_version      = "v1.10.6"

  talos_nodes = {
    cp1 = {
      ip_address   = "10.0.1.10"
      ip_subnet    = 24
      machine_type = "controlplane"
    }
    cp2 = {
      ip_address   = "10.0.1.11"
      ip_subnet    = 24
      machine_type = "controlplane"
    }
    cp3 = {
      ip_address   = "10.0.1.12"
      ip_subnet    = 24
      machine_type = "controlplane"
    }
    worker1 = {
      ip_address   = "10.0.1.20"
      ip_subnet    = 24
      machine_type = "worker"
    }
    worker2 = {
      ip_address   = "10.0.1.21"
      ip_subnet    = 24
      machine_type = "worker"
    }
  }

  metrics_server = {
    enabled = true
  }

  create_kubeconfig_file  = true
  create_talosconfig_file = true
}
```

### With External CNI (e.g., Cilium)

```hcl
module "talos_cluster" {
  source = "path/to/terraform-talos-cluster"

  cluster_name       = "cilium-cluster"
  kubernetes_version = "v1.33.3"
  talos_version      = "v1.10.6"

  talos_nodes = {
    cp1 = {
      ip_address   = "10.0.1.10"
      ip_subnet    = 24
      machine_type = "controlplane"
    }
    worker1 = {
      ip_address   = "10.0.1.20"
      ip_subnet    = 24
      machine_type = "worker"
    }
  }

  # Disable default CNI and kube-proxy for Cilium
  disable_cni        = true
  disable_kube_proxy = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.11.0 |
| local | 2.6.1 |
| talos | 0.9.0 |

## Providers

| Name | Version |
|------|---------|
| [local](https://registry.terraform.io/providers/hashicorp/local/latest) | 2.6.1 |
| [talos](https://registry.terraform.io/providers/siderolabs/talos/latest) | 0.9.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Talos cluster name | `string` | `"talos"` | no |
| cluster_vip | Talos cluster control plane VIP for high availability | `string` | `null` | no |
| kubernetes_version | Kubernetes cluster version | `string` | `"v1.33.3"` | no |
| talos_version | Talos node version | `string` | `"v1.10.6"` | no |
| talos_nodes | Map of nodes with their configuration | `map(object({ ip_address = string, ip_subnet = number, machine_type = string }))` | n/a | yes |
| metrics_server | Enable metrics server and certificate rotation | `object({ enabled = optional(bool, false), extra_manifests = optional(list(string), [...]) })` | see below | no |
| scheduling_on_control_planes | Allow workload scheduling on control plane nodes | `bool` | `false` | no |
| disable_cni | Disable Talos default CNI (Flannel) | `bool` | `false` | no |
| disable_kube_proxy | Disable Talos kube-proxy | `bool` | `false` | no |
| create_kubeconfig_file | Create a kubeconfig file locally | `bool` | `false` | no |
| create_talosconfig_file | Create a talosconfig file locally | `bool` | `false` | no |

### metrics_server default value

```hcl
{
  enabled = false
  extra_manifests = [
    "https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml",
    "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
  ]
}
```

## Outputs

| Name | Description | Sensitive |
|------|-------------|:---------:|
| talos_client_config | Talos client configuration in HCL format | yes |
| kubeconfig | Kubeconfig for the Talos cluster (raw YAML) | yes |
| kube_client_config | Kubeconfig in HCL format | yes |
| kube_endpoint | Kubernetes cluster control plane endpoint URL | no |

## Notes

### Health Checks

The module waits for the cluster to become healthy before generating outputs. The health check has a 10-minute timeout. When `disable_cni` or `disable_kube_proxy` is set to `true`, Kubernetes-level health checks are skipped since the cluster won't be fully functional until an external CNI is deployed.

### Credential Files

When `create_kubeconfig_file` or `create_talosconfig_file` is enabled, credentials are written to:
- `./<cluster_name>.kubeconfig`
- `./<cluster_name>.talosconfig`

These files contain sensitive credentials. Ensure they are added to `.gitignore` to prevent accidental commits.

### VIP Configuration

When `cluster_vip` is specified, the module configures a Virtual IP on control plane nodes using Talos's built-in VIP support. This requires:
- The VIP address to be in the same subnet as the control plane nodes
- Layer 2 network connectivity between control plane nodes

## Resources Created

- `talos_machine_secrets` - Machine secrets for secure communication
- `talos_machine_configuration` - Per-node Talos configuration (data source)
- `talos_machine_configuration_apply` - Applies configuration to each node
- `talos_machine_bootstrap` - Bootstraps the first control plane node
- `talos_cluster_kubeconfig` - Generates Kubernetes credentials
- `local_file` - Optional local credential files
