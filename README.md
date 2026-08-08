# OpenTofu Talos Cluster

OpenTofu module to bootstrap a [Talos Linux](https://www.talos.dev/) Kubernetes cluster from a list of pre-provisioned nodes.

![OpenTofu](https://img.shields.io/badge/opentofu-%3E%3D1.11.0-blue)
![Talos Provider](https://img.shields.io/badge/talos--provider-0.11.0-purple)

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
  kubernetes_version = "v1.35.4"
  talos_version      = "v1.12.11"

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

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | 2.9.0 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | 0.11.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | 2.9.0 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.11.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [local_file.kubeconfig](https://registry.terraform.io/providers/hashicorp/local/2.9.0/docs/resources/file) | resource |
| [local_file.talosconfig](https://registry.terraform.io/providers/hashicorp/local/2.9.0/docs/resources/file) | resource |
| [talos_cluster_kubeconfig.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/resources/cluster_kubeconfig) | resource |
| [talos_machine_bootstrap.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/resources/machine_bootstrap) | resource |
| [talos_machine_configuration_apply.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/resources/machine_configuration_apply) | resource |
| [talos_machine_secrets.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/resources/machine_secrets) | resource |
| [talos_client_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/data-sources/client_configuration) | data source |
| [talos_cluster_health.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/data-sources/cluster_health) | data source |
| [talos_machine_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/data-sources/machine_configuration) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Talos cluster name | `string` | `"talos"` | no |
| <a name="input_cluster_vip"></a> [cluster\_vip](#input\_cluster\_vip) | Talos cluster control plane VIP | `string` | `null` | no |
| <a name="input_create_kubeconfig_file"></a> [create\_kubeconfig\_file](#input\_create\_kubeconfig\_file) | Whether you want to create a kubeconfig file locally (it's still available as tf output) | `bool` | `false` | no |
| <a name="input_create_talosconfig_file"></a> [create\_talosconfig\_file](#input\_create\_talosconfig\_file) | Whether you want to create a talosconfig file locally (it's still available as tf output) | `bool` | `false` | no |
| <a name="input_disable_cni"></a> [disable\_cni](#input\_disable\_cni) | Disable Talos default CNI (Flannel) | `bool` | `false` | no |
| <a name="input_disable_kube_proxy"></a> [disable\_kube\_proxy](#input\_disable\_kube\_proxy) | Disable Talos kube-proxy | `bool` | `false` | no |
| <a name="input_extra_manifests"></a> [extra\_manifests](#input\_extra\_manifests) | URLs of additional manifests for Talos to apply during bootstrap, appended<br/>to `cluster.extraManifests`.<br/><br/>Fetched by the control plane at bootstrap, so every URL must be reachable<br/>from the nodes themselves -- not from wherever OpenTofu runs. Use<br/>`inline_manifests` for anything that is not publicly hosted.<br/><br/>These are applied once, at bootstrap, and are not reconciled afterwards.<br/>Anything that should stay reconciled belongs in a GitOps controller, not<br/>here. The exception is what has to exist *before* such a controller can<br/>run at all: with `disable_cni = true` there is no pod network, so a CNI<br/>cannot be installed by anything that needs to schedule a pod. | `list(string)` | `[]` | no |
| <a name="input_inline_manifests"></a> [inline\_manifests](#input\_inline\_manifests) | Manifests embedded directly in the machine configuration, as<br/>`cluster.inlineManifests`.<br/><br/>Unlike `extra_manifests` these need no network fetch, which makes them the<br/>right choice for air-gapped clusters or for rendered output such as<br/>`helm template`. They travel inside the machine config and therefore end<br/>up in OpenTofu state -- keep secrets out of them. | <pre>list(object({<br/>    name     = string<br/>    contents = string<br/>  }))</pre> | `[]` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes cluster version | `string` | `"v1.35.4"` | no |
| <a name="input_metrics_server"></a> [metrics\_server](#input\_metrics\_server) | Enable kubernetes certificate rotation | <pre>object({<br/>    enabled = optional(bool, false)<br/>    extra_manifests = optional(list(string), [<br/>      "https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml",<br/>      "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"<br/>    ])<br/>  })</pre> | n/a | yes |
| <a name="input_scheduling_on_control_planes"></a> [scheduling\_on\_control\_planes](#input\_scheduling\_on\_control\_planes) | Allow workload scheduling on control plane nodes | `bool` | `false` | no |
| <a name="input_talos_nodes"></a> [talos\_nodes](#input\_talos\_nodes) | n/a | <pre>map(object({<br/>    ip_address   = string<br/>    ip_subnet    = number<br/>    machine_type = string<br/>  }))</pre> | n/a | yes |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | Talos node version | `string` | `"v1.12.11"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_kube_client_config"></a> [kube\_client\_config](#output\_kube\_client\_config) | Kubernetes client configuration, for configuring the kubernetes and helm providers without parsing the raw kubeconfig YAML. |
| <a name="output_kube_endpoint"></a> [kube\_endpoint](#output\_kube\_endpoint) | Kubernetes cluster control plane endpoint |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubeconfig for the Talos cluster |
| <a name="output_talos_client_config"></a> [talos\_client\_config](#output\_talos\_client\_config) | Talos client configuration in HCL format |
<!-- END_TF_DOCS -->