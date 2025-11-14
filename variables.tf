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
  default     = "v1.33.3"
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
  default     = "v1.10.6"
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
