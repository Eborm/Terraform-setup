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

module "proxmox" {
  source = "./proxmox"
}

module "talos-config" {
  source = "./talos-config"

  control_nodes = module.proxmox.control_nodes

  worker_nodes = module.proxmox.worker_nodes

  cluster_vip = "192.168.68.195"

  depends_on = [
    module.proxmox
  ]
}
