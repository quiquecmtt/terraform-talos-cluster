output "talos_client_config" {
  depends_on = [
    talos_machine_bootstrap.this,
    data.talos_cluster_health.this
  ]
  description = "Talos client configuration in HCL format"
  value       = data.talos_client_configuration.this.client_configuration
  sensitive   = true
}

output "kubeconfig" {
  depends_on = [
    talos_machine_bootstrap.this,
    data.talos_cluster_health.this
  ]
  description = "Kubeconfig for the Talos cluster"
  value       = resource.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "kube_client_config" {
  depends_on = [
    talos_machine_bootstrap.this,
    data.talos_cluster_health.this
  ]
  description = "Kubernetes client configuration, for configuring the kubernetes and helm providers without parsing the raw kubeconfig YAML."
  value       = resource.talos_cluster_kubeconfig.this.kubernetes_client_configuration
  sensitive   = true
}

output "kube_endpoint" {
  depends_on = [
    talos_machine_bootstrap.this,
    data.talos_cluster_health.this
  ]
  description = "Kubernetes cluster control plane endpoint"
  value       = "https://${local.cluster_endpoint}:6443"
  sensitive   = false
}
