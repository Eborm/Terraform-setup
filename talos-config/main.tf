terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.11.0"
    }
  }
}

//Setup local cluster variables
locals {
  cluster_name     = "Homelab" //Set this to the wanted name. I still need to think of something
  cluster_endpoint = "https://192.168.68.191:6443" //Set this to the ip of one of your control nodes or your vip if you will be using a virtual ip for you cluster
}

//Get the ip addresses for your worker nodes so these can be properly added into the cluster
locals {
  worker_ips = {
    for name, worker in var.worker_nodes :
    name => one([
      for ip in flatten(worker.ip_addresses) :
      ip
      if startswith(ip, "192.168.68.")
    ])
  }
}

//Generate talos machine secrets
resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name     = local.cluster_name
  cluster_endpoint = local.cluster_endpoint

  machine_type = "controlplane"

  machine_secrets = talos_machine_secrets.this.machine_secrets

  talos_version = "v1.13.0"

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
          image = "factory.talos.dev/nocloud-installer/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515:v1.13.0"
        }
      }
    })
  ]
}

resource "talos_machine_configuration_apply" "controlplane" {
  for_each = var.control_nodes
  node     = each.value.ip_address

  client_configuration = talos_machine_secrets.this.client_configuration

  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
}

resource "talos_machine_bootstrap" "this" {
    node = var.control_nodes["cp-01"].ip_address

    client_configuration = talos_machine_secrets.this.client_configuration

    depends_on = [
        talos_machine_configuration_apply.controlplane
    ]
}

resource "talos_cluster_kubeconfig" "this" {
  node = var.control_nodes["cp-01"].ip_address

  client_configuration = talos_machine_secrets.this.client_configuration

  depends_on = [
    talos_machine_bootstrap.this
  ]
}

data "talos_machine_configuration" "worker" {
  cluster_name     = local.cluster_name
  cluster_endpoint = local.cluster_endpoint

  machine_type = "worker"

  machine_secrets = talos_machine_secrets.this.machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
          image = "factory.talos.dev/nocloud-installer/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515:v1.13.0"
        }
      }
    })
  ]
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = var.worker_nodes

  node = local.worker_ips[each.key]

  client_configuration = talos_machine_secrets.this.client_configuration

  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration

  depends_on = [
    talos_machine_bootstrap.this
  ]
}

output "worker_ips_debug" {
  value = local.worker_ips
}