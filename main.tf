terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.113.1"
    }

    talos = {
      source  = "siderolabs/talos"
      version = "0.11.0"
    }
  }
}


provider "proxmox" {
  endpoint = "https://192.168.68.180:8006/" //local url

  password = var.proxmox_password
  username = var.proxmox_username

  insecure = true
}

provider "talos" {}

variable "proxmox-nodes" {
  type = set(string)
  default = [
    "clanker-01",
    "clanker-02",
    "clanker-03",
  ]
}

module "kubernetes" {
  source = "./kubernetes"
}

module "talos-config" {
  source = "./talos-config"

  control_nodes = module.kubernetes.control_nodes

  worker_nodes = module.kubernetes.worker_nodes

  depends_on = [
    module.kubernetes
  ]
}
