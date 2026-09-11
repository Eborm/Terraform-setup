terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.113.1"
    }
  }
}

locals {
    talos_control_node = {
        "cp-01" = {
            target_node = "clanker-02" //change to clanker-01 for prod
        }//, These nodes will be added in the future this is for now to try it out
        //"cp-02" = {
        //    target_node = "clanker-01"
        //}
        //"cp-03" = {
        //    target_node = "clanker-02"
        //}
    }

    talos_worker_node = {
        //for the test run only create one worker node instead of all 3
        "temp_wn" = {
            target_node = "clanker-02"
            memory = 6144
        }
        //"wn-01" = {
        //    target_node = "clanker-01"
        //    memory = 12288
        //},
        //"wn-02" = {
        //    target_node = "clanker-01"
        //    memory = 12288
        //},
        //"wn-03" = {
        //    target_node = "clanker-02",
        //    memory = 24576 //Adjusted because this node only has 8 cores not 12. 
        //}
    }
}

resource "proxmox_virtual_environment_vm" "Control_node" {
    for_each = local.talos_control_node //Creates a VM for each control node defined in the code block above
    
    name = each.key //Grabs the name from the control node definition
    node_name = each.value.target_node //Grabs the target node from the control node definition

    agent {
        enabled = true //enables the Qemu guest agent
    }

    cpu {
        cores = 2 //2 cores can be adjusted but is recomended for Talos
        type = "host"
    }

    memory {
        dedicated = 4096 // 4 Gigabytes of ram can be adjusted but is recomended for Talos 
        floating = 0 //This is for ballooning set it to dedicated to enable it
    }

    cdrom {
        file_id = "local:iso/Talos_USE_THIS_-nocloud-amd64.iso"
        interface = "ide2"
    }

    disk {
        datastore_id = "local-lvm"
        interface = "scsi0"
        size = 40
    }

    network_device {
        bridge = "vmbr0"
        model = "e1000"
    }
}