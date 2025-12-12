locals {
  first_control_plane_node_ip = [for k, v in var.talos_nodes : v.ip_address if v.machine_type == "controlplane"][0]
  cluster_endpoint            = coalesce(var.cluster_vip, local.first_control_plane_node_ip)
  extra_manifests = concat(
    var.metrics_server.enabled ? var.metrics_server.extra_manifests : []
  )
}

