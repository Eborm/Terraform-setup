terraform {
  required_providers {
    proxmox = {
      source  = "Terraform-for-Proxmox/proxmox"
      version = "0.0.1"
    }
  }
}

provider "proxmox" {
  pm_api_url = "https://192.168.68.180:8006/api2/json"
}

