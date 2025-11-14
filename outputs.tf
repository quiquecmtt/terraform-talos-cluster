output "talos_client_config" {
  description = "Talos client configuration in HCL format"
  value       = data.talos_client_configuration.this.client_configuration
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubeconfig for the Talos cluster"
  value       = resource.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "kube_client_config" {
  description = "Kubeconfig in HCL format"
  value       = resource.talos_cluster_kubeconfig.this.client_configuration
  sensitive   = true
}

output "kube_endpoint" {
  description = "Kubernetes cluster control plane endpoint"
  value       = "https://${local.cluster_endpoint}:6443"
  sensitive   = false
}
