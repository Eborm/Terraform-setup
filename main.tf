terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.113.1"
    }
  }
}


provider "proxmox" {
  endpoint = "https://192.168.68.180:8006/api2/json" //local url
  
  password = var.proxmox_password
  username = var.proxmox_username

  insecure = true
}

variable proxmox-nodes {
  type        = set(string)
  default     = [
    "clanker-01",
    "clanker-02",
  ]
}

module "kubernetes" {
  source = "./kubernetes"
}
