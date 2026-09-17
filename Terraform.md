# Set up proxmox user, permissions and provider for Terraform.

### Create Terraform role and add permissions
Based on exact needs this should be changed.
``` c#
pveum role modify TerraformProv -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.PowerMgmt SDN.Use"
```

### Create and set password for Terraform user
Save the password somowhere you will need it again
``` c#
pveum user add terraform-prov@pve --password <TerraformUserPassword>
```

### Add the Terraform role to the Terraform user

``` c#
pveum aclmod / -user terraform-prov@pve -role TerraformProv
```

# Create Terraform proxmox provider
Steps to create the Terraform proxmox provider.

### Setup enviorment variables in Terraform for proxmox
Create a file names variables.tf and add in this so terraform can read your password and username that will be added in secrets.auto.tfvars
``` c#
variable "proxmox_username" {
  type      = string
  sensitive = true
}

variable "proxmox_password" {
  type      = string
  sensitive = true
}
```

And create secrets.auto.tfvars and add your username and password to it
``` c#
proxmox_username = "terraform-prov@pve"
proxmox_password = "Your-Proxmox-Password"
```

### Create main.tf
This setups the Terraform provider for proxmox allowing Terraform to create destroy and edit VM's in proxmox.
``` c#
terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}
```

### Enter the right directory and initialize terraform
``` c#
teraform init
```

### From the init add version flag to main.tf
The init will give you back the current version number for Terraform-for-proxmox. It is smart to add this to your main.tf file so the version doesn't change and destroy your setup.
``` c#
terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "version_number"
    }
  }
}
```

### Add proxmox provider to main.tf
This is what finally lets Terraform talk to the provider we created. After this you can setup your VM's and such
``` c#
provider "proxmox" {
  endpoint = "https://proxmox.server.url/api2/json"

  password = var.proxmox_password
  username = var.proxmox_username

  insecure = true
}
```

# Setting up the VM's and nodes

### Set up the nodes for Terraform to use
Replace all the nodes with the correct names and amount of nodes.
``` c#
variable proxmox-nodes {
  type        = set(string)
  default     = [
    "node-1",
    "node-2",
  ]
}
```

### Create proxmox module
From the terminal run
``` c#
mkdir proxmox
```

In main.tf add so it can access the file in the proxmox folder where we will add all of our virtual machines
``` c#
module "proxmox" {
  source = "./proxmox"
}
```

### Setting up the VM's
In the folder proxmox create a main.tf file. Within this file we will define our VM's for the Talos kubernetes cluster

### Defining how many control nodes and worker nodes
Within the file create 2 local variables like this and add the required providers you do not need to add the provider itself again
``` c#
terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "version_number"
    }
  }
}

local {
    talos_control_node = {
        "cp-01" = {
            target_node = "node-1" //replace with the target node 
        }
    }

    talos_worker_node = {
        "wn-01" = {
            target_node = "node-1" //replace with the target node
            memory = 8192 //8 Gb of ram. Change this to the appropriate amount for your worker.
            cores = 4 //Recommended for tallos worker node
        },
        "wn-02" = {
            target_node = "node-1" //replace with the target node
            memory = 8192 //8 Gb of ram. Change this to the appropriate amount for your worker.
            cores = 4 //Recommended for tallos worker node
        }
    }
}
```
Within these variables you define your VM's as a example i have added 1 control node and 2 worker nodes you can scale this up as you need.

### Defining the control node
Here you define what resources your control node has
``` c#

resource "proxmox_virtual_environment_vm" "Control_node" {
    for_each = local.talos_control_node //Creates a VM for each control node defined in the code block above
    
    name = each.key //Grabs the name from the control node definition
    node_name = each.value.target_node //Grabs the target node from the control node definition

    boot_order = ["scsi0", "ide2"] //This is so it always boots from disk first

    agent {
        enabled = true //enables the Qemu guest agent
    }

    cpu {
        cores = 2 //2 cores can be adjusted but is recomended for Talos control node
        type = "host" //Using type host
    }

    memory {
        dedicated = 4096 // 4 Gigabytes of ram can be adjusted but is recomended for Talos 
        floating = 0 //This is for ballooning set it to dedicated to enable it
    }

    cdrom {
        file_id = "Storage-Iso-Is-Saved-On:iso/Set-To-Right-Iso-File-Name"
        interface = "ide2"
    }

    disk {
        datastore_id = "local-lvm" //Set this to the right datastorage
        interface = "scsi0"
        size = 40 //40 Gib disk 
    }

    network_device {
        bridge = "vmbr0"
        model = "e1000" //I am using e1000 because other wise i get problems. Use what ever you need
    }
}
``` 

### Defining the worker node
``` c#
resource "proxmox_virtual_environment_vm" "Worker_node" {
    for_each = local.talos_worker_node //Creates a VM for each Worker node defined in the code block above
    
    name = each.key //Grabs the name from the Worker node node definition
    node_name = each.value.target_node //Grabs the target node from the Worker node definition

    boot_order = ["scsi0", "ide2"]

    agent {
        enabled = true //enables the Qemu guest agent
    }

    cpu {
        cores = each.value.cores
        type = "host"
    }

    memory {
        dedicated = each.value.memory //Defined in the worker node
        floating = 0 //This is for ballooning set it to dedicated to enable it
    }

    cdrom {
        file_id = "Storage-Iso-Is-Saved-On:iso/Set-To-Right-Iso-File-Name"
        interface = "ide2"
    }

    disk {
        datastore_id = "local-lvm" //Set this to the right datastorage
        interface = "scsi0"
        size = 50 //50 Gib disk 
    }

    network_device {
        bridge = "vmbr0"
        model = "e1000" //I am using e1000 because other wise i get problems. Use what ever you need
    }
}
```