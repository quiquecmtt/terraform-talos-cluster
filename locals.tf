locals {
  first_control_plane_node_ip = [for k, v in var.talos_nodes : v.ip_address if v.machine_type == "controlplane"][0]
  cluster_endpoint            = coalesce(var.cluster_vip, local.first_control_plane_node_ip)
  # Caller-supplied URLs come last so they apply after the metrics-server set,
  # which is what you want if one depends on the other -- Talos applies
  # extraManifests in order.
  extra_manifests = concat(
    var.metrics_server.enabled ? var.metrics_server.extra_manifests : [],
    var.extra_manifests
  )
}

