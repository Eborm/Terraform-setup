terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.113.1"
    }
  }
}

locals {
  talos_control_node = {
    "cp-01" = {
      target_node = "clanker-01"
      mac_address = "BC:24:11:13:8F:60"
      ip_address  = "192.168.68.191"
    },
    "cp-02" = {
      target_node = "clanker-02"
      mac_address = "BC:24:11:17:F4:4D"
      ip_address  = "192.168.68.192"
    },
    "cp-03" = {
      target_node = "clanker-03"
      mac_address = "BC:24:11:E7:8F:17"
      ip_address  = "192.168.68.193"
    }
  }

  talos_worker_node = {
    "wn-01" = {
      target_node = "clanker-01"
      cores       = 4
      memory      = 14336
    },
    "wn-02" = {
      cores       = 4
      target_node = "clanker-01"
      memory      = 14336
    },
    "wn-03" = {
      cores       = 2
      target_node = "clanker-02",
      memory      = 12288
    },
    "wn-04" = {
      cores       = 2
      target_node = "clanker-02",
      memory      = 12288
    },
  }
}

resource "proxmox_virtual_environment_vm" "Control_node" {
  for_each = local.talos_control_node //Creates a VM for each control node defined in the code block above

  name      = each.key               //Grabs the name from the control node definition
  node_name = each.value.target_node //Grabs the target node from the control node definition

  boot_order = ["scsi0", "ide2"]

  agent {
    enabled = true //enables the Qemu guest agent

    wait_for_ip {
      disabled = false
    }
  }

  cpu {
    cores = 2 //2 cores can be adjusted but is recomended for Talos control node
    type  = "host"
  }

  memory {
    dedicated = 4096 // 4 Gigabytes of ram can be adjusted but is recomended for Talos 
    floating  = 0    //This is for ballooning set it to dedicated to enable it
  }

  cdrom {
    file_id   = "local:iso/talos-nocloud-amd64-with-qemu.iso"
    interface = "ide2"
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 40
  }

  network_device {
    bridge      = "vmbr0"
    model       = "e1000"
    mac_address = each.value.mac_address
  }
}

resource "proxmox_virtual_environment_vm" "Worker_node" {
  for_each = local.talos_worker_node //Creates a VM for each Worker node defined in the code block above

  name      = each.key               //Grabs the name from the Worker node node definition
  node_name = each.value.target_node //Grabs the target node from the Worker node definition

  boot_order = ["scsi0", "ide2"]

  agent {
    enabled = true //enables the Qemu guest agent
    
    wait_for_ip {
      disabled = false
    }
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory //Defined in the worker node
    floating  = 0                 //This is for ballooning set it to dedicated to enable it
  }

  cdrom {
    file_id   = "local:iso/talos-nocloud-amd64-with-qemu.iso"
    interface = "ide2"
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 50
  }

  network_device {
    bridge = "vmbr0"
    model  = "e1000"
  }
}