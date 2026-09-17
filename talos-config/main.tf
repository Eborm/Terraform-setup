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

  //Get the ip addresses for your worker nodes so these can be properly added into the cluster
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

//Create the config for the talos control plane nodes. 
data "talos_machine_configuration" "controlplane" {
  cluster_name     = local.cluster_name // Cluster name
  cluster_endpoint = local.cluster_endpoint // cluster endpoint. --> Currently cp-01 (control plane node 1)

  machine_type = "controlplane" //Set the machine type to controlplane

  machine_secrets = talos_machine_secrets.this.machine_secrets //Use the machine secrets generated to create or join the cluster

  talos_version = "v1.13.0" //Specify talos version

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda" //Specify installation disk
          image = "factory.talos.dev/nocloud-installer/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515:v1.13.0" //No-cloud talos version 1.13.0 with qemu guest agent extension installed
        }
      }
    })
  ]
}

//Apply the controlplane configuration to all controlplane nodes
resource "talos_machine_configuration_apply" "controlplane" {
  for_each = var.control_nodes
  node     = each.value.ip_address

  client_configuration = talos_machine_secrets.this.client_configuration

  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
}

//Start kubernetes contorlplane node at cp-01
resource "talos_machine_bootstrap" "this" {
    node = var.control_nodes["cp-01"].ip_address

    client_configuration = talos_machine_secrets.this.client_configuration

    depends_on = [
        talos_machine_configuration_apply.controlplane
    ]
}

//Retrieves the kube config for the talos cluster. Unsure if this actually does what i just wrote but thats what the documentation says i think.
resource "talos_cluster_kubeconfig" "this" {
  node = var.control_nodes["cp-01"].ip_address

  client_configuration = talos_machine_secrets.this.client_configuration

  depends_on = [
    talos_machine_bootstrap.this
  ]
}

//Create the configuration for workerplanes
data "talos_machine_configuration" "worker" {
  cluster_name     = local.cluster_name //Clustername
  cluster_endpoint = local.cluster_endpoint //Clusterendpoint currently cp-01

  machine_type = "worker" //Specify machine type to be workerplane

  machine_secrets = talos_machine_secrets.this.machine_secrets

  //Its the same as the controlplane its nothing special
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

//Apply workerplane configuration to worker nodes
resource "talos_machine_configuration_apply" "worker" {
  for_each = var.worker_nodes

  node = local.worker_ips[each.key]

  client_configuration = talos_machine_secrets.this.client_configuration

  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration

  depends_on = [
    talos_machine_bootstrap.this
  ]
}
