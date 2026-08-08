variable "cluster_name" {
  description = "Talos cluster name"
  type        = string
  default     = "talos"
  sensitive   = false
}

variable "cluster_vip" {
  description = "Talos cluster control plane VIP"
  type        = string
  nullable    = true
  sensitive   = false
  default     = null
}

variable "kubernetes_version" {
  description = "Kubernetes cluster version"
  type        = string
  sensitive   = false
  default     = "v1.35.4"
}

variable "talos_nodes" {
  type = map(object({
    ip_address   = string
    ip_subnet    = number
    machine_type = string
  }))
}

variable "metrics_server" {
  description = "Enable kubernetes certificate rotation"
  type = object({
    enabled = optional(bool, false)
    extra_manifests = optional(list(string), [
      "https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml",
      "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
    ])
  })
  sensitive = false
}

variable "scheduling_on_control_planes" {
  description = "Allow workload scheduling on control plane nodes"
  type        = bool
  sensitive   = false
  default     = false
}

variable "talos_version" {
  description = "Talos node version"
  type        = string
  sensitive   = false
  default     = "v1.12.11"
}

variable "extra_manifests" {
  description = <<-EOT
    URLs of additional manifests for Talos to apply during bootstrap, appended
    to `cluster.extraManifests`.

    Fetched by the control plane at bootstrap, so every URL must be reachable
    from the nodes themselves -- not from wherever OpenTofu runs. Use
    `inline_manifests` for anything that is not publicly hosted.

    These are applied once, at bootstrap, and are not reconciled afterwards.
    Anything that should stay reconciled belongs in a GitOps controller, not
    here. The exception is what has to exist *before* such a controller can
    run at all: with `disable_cni = true` there is no pod network, so a CNI
    cannot be installed by anything that needs to schedule a pod.
  EOT
  type        = list(string)
  sensitive   = false
  default     = []
}

variable "inline_manifests" {
  description = <<-EOT
    Manifests embedded directly in the machine configuration, as
    `cluster.inlineManifests`.

    Unlike `extra_manifests` these need no network fetch, which makes them the
    right choice for air-gapped clusters or for rendered output such as
    `helm template`. They travel inside the machine config and therefore end
    up in OpenTofu state -- keep secrets out of them.
  EOT
  type = list(object({
    name     = string
    contents = string
  }))
  sensitive = false
  default   = []
}

variable "disable_cni" {
  description = "Disable Talos default CNI (Flannel)"
  type        = bool
  sensitive   = false
  default     = false
}

variable "disable_kube_proxy" {
  description = "Disable Talos kube-proxy"
  type        = bool
  sensitive   = false
  default     = false
}

variable "create_kubeconfig_file" {
  description = "Whether you want to create a kubeconfig file locally (it's still available as tf output)"
  type        = bool
  sensitive   = false
  default     = false
}

variable "create_talosconfig_file" {
  description = "Whether you want to create a talosconfig file locally (it's still available as tf output)"
  type        = bool
  sensitive   = false
  default     = false
}

