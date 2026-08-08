# OpenTofu Talos Cluster

OpenTofu module to bootstrap a [Talos Linux](https://www.talos.dev/) Kubernetes cluster from a list of pre-provisioned nodes.

![OpenTofu](https://img.shields.io/badge/opentofu-%3E%3D1.11.0-blue)
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

- **OpenTofu** >= 1.11.0 installed
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
  kubernetes_version = "v1.35.4"
  talos_version      = "v1.12.11"

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

With `disable_cni = true` the nodes stay `NotReady` until a CNI is installed,
and nothing that needs to schedule a pod can run until then. There are two
ways to close that gap.

### Bootstrap manifests

`extra_manifests` takes URLs, which the **control plane** fetches during
bootstrap — so they must be reachable from the nodes, not from wherever
OpenTofu runs.

```hcl
module "talos_cluster" {
  # ...
  disable_cni = true

  extra_manifests = [
    "https://raw.githubusercontent.com/example/org/main/cni.yaml",
  ]
}
```

`inline_manifests` embeds the content in the machine configuration instead, so
no fetch happens at all. That suits air-gapped clusters, and rendered output
such as `helm template`:

```hcl
module "talos_cluster" {
  # ...
  disable_cni = true

  inline_manifests = [{
    name     = "cilium"
    contents = data.helm_template.cilium.manifest
  }]
}
```

Both are applied **once, at bootstrap, and are never reconciled afterwards**.
Anything that should stay reconciled belongs in a GitOps controller. Reserve
these for what must exist before such a controller can run at all — which is
essentially just the CNI.

Inline manifests travel inside the machine configuration and therefore land in
OpenTofu state. Keep secrets out of them.

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

### Manifests

`extra_manifests` and `inline_manifests` are applied once during bootstrap and are never reconciled afterwards. If a manifest is edited, removed, or drifts in the cluster, nothing here notices or corrects it — that is a GitOps controller's job.

They exist for what has to be in place *before* such a controller can run. With `disable_cni = true` there is no pod network, so a CNI cannot be installed by anything that needs to schedule a pod. That is the case worth using them for; almost everything else is better owned by Flux or Argo.

Choose between them by whether the nodes can reach the content: `extra_manifests` is fetched by the control plane at bootstrap and needs network access from the nodes, while `inline_manifests` travels inside the machine configuration and needs none. Inline content is stored in OpenTofu state, so keep secrets out of it.

### Why `.tf` and not `.tofu`

This module is OpenTofu-only — it requires >= 1.11.0 and uses `lifecycle.enabled`, which Terraform does not support — but its files are named `.tf`.

That is a concession to tooling. terraform-docs added `.tofu` support in v0.20.0, but [only for headers and footers](https://github.com/terraform-docs/terraform-docs/releases/tag/v0.20.0): it still cannot parse them for inputs, outputs or providers. With `.tofu` files the generated block below came out empty, so the requirement and input tables had to be written by hand — and they drifted, claiming `talos 0.9.0` against an actual `0.11.0`.

The `.tofu` extension buys exactly one thing: Terraform ignores the files rather than erroring on them. That is not worth documentation that silently rots. Requirements, providers, inputs and outputs are now generated from the source instead.

## Resources Created

- `talos_machine_secrets` - Machine secrets for secure communication
- `talos_machine_configuration` - Per-node Talos configuration (data source)
- `talos_machine_configuration_apply` - Applies configuration to each node
- `talos_machine_bootstrap` - Bootstraps the first control plane node
- `talos_cluster_kubeconfig` - Generates Kubernetes credentials
- `local_file` - Optional local credential files

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END_TF_DOCS -->