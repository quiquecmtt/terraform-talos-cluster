resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [for k, v in var.talos_nodes : v.ip_address]
  endpoints            = [for k, v in var.talos_nodes : v.ip_address if v.machine_type == "controlplane"]
}

data "talos_machine_configuration" "this" {
  for_each = var.talos_nodes

  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${local.cluster_endpoint}:6443"
  machine_type       = each.value.machine_type
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.kubernetes_version
  config_patches = [
    # Common
    yamlencode({
      cluster = {
        allowSchedulingOnControlPlanes = var.scheduling_on_control_planes
      },
      machine = {
        kubelet = {
          extraArgs = {
            rotate-server-certificates = var.metrics_server.enabled
          }
        }
      }
    }), each.value.machine_type == "controlplane" ?
    # Control plane
    yamlencode({
      cluster = {
        extraManifests = local.extra_manifests
        network = {
          cni = {
            name = var.disable_cni ? "none" : "flannel"
          }
        }
        proxy = {
          disabled = var.disable_kube_proxy
        }
      }
      machine = {
        network = {
          interfaces = var.cluster_vip != null && var.cluster_vip != "" ? [{
            deviceSelector = { physical = true }
            vip            = { ip = var.cluster_vip }
          }] : []
        }
      }
    }) :
    # Worker
    yamlencode({

    })
  ]
}

resource "talos_machine_configuration_apply" "this" {
  for_each = var.talos_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  node                        = each.value.ip_address
}

resource "talos_machine_bootstrap" "this" {
  depends_on           = [talos_machine_configuration_apply.this]
  node                 = local.first_control_plane_node_ip
  client_configuration = talos_machine_secrets.this.client_configuration
}

data "talos_cluster_health" "this" {
  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_bootstrap.this
  ]
  skip_kubernetes_checks = var.disable_cni || var.disable_kube_proxy ? true : false
  client_configuration   = data.talos_client_configuration.this.client_configuration
  control_plane_nodes    = [for k, v in var.talos_nodes : v.ip_address if v.machine_type == "controlplane"]
  worker_nodes           = [for k, v in var.talos_nodes : v.ip_address if v.machine_type == "worker"]
  endpoints              = data.talos_client_configuration.this.endpoints
  timeouts = {
    read = "10m"
  }
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this,
    data.talos_cluster_health.this
  ]
  # The kubeconfig endpoint will be populated from the talos_machine_configuration cluster_endpoint
  node                 = local.cluster_endpoint
  client_configuration = talos_machine_secrets.this.client_configuration
  timeouts = {
    read = "1m"
  }
}

resource "local_file" "talosconfig" {
  content = yamlencode({
    context = var.cluster_name
    contexts = {
      (var.cluster_name) = {
        endpoints = data.talos_client_configuration.this.endpoints
        ca        = data.talos_client_configuration.this.client_configuration.ca_certificate
        crt       = data.talos_client_configuration.this.client_configuration.client_certificate
        key       = data.talos_client_configuration.this.client_configuration.client_key
      }
    }
  })
  filename = "./${var.cluster_name}.talosconfig"
}

resource "local_file" "kubeconfig" {
  content  = resource.talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = "./${var.cluster_name}.kubeconfig"
}
