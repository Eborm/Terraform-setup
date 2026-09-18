# Set up the talos cluster and make it ready for pods
This file assumes you have also updated the proxmox configuration using the `Proxmox-update.md`

### Export controlplane and workerplane ip's

Within the folder proxmox create a `outputs.tf` file. This is the file we will use to extract the ip's from the vm's we created.
Within this file create these 2 ouputs.
``` c#
//This exports the control nodes in full including mac adress, taget-node and most importantly ip.
output "control_nodes" {
  value = local.talos_control_node
}

//This exports the worker nodes ip's using the proxmox qemu agent.
output "worker_nodes" {
  value = {
    for name, vm in proxmox_virtual_environment_vm.Worker_node : name => {
      ip_addresses = vm.ipv4_addresses
    }
  }
}
```

### Adding the Talos provider


#### Initilizing the Talos provider
Similar to what we did with the proxmox provider we will first add the provider to our `main.tf` file.
``` c#
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "Your proxmox provider version"
    }

    talos = {
      source  = "siderolabs/talos"
    }
  }
}

```

After this run `terraform init`

From this note down the version number and add it to the terraform provider 
``` c#
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "Your proxmox provider version"
    }

    talos = {
      source  = "siderolabs/talos"
      version = "Your talos provider version"
    }
  }
}
```

#### Creating the provider
In the `main.tf` file add in the talos provider
``` c#
provider "talos" {}
```

After this create a folder called talos config by running `mkdir talos-config`

Now we can add the module to the `main.tf` file finishing our work here.

``` c#
module "talos-config" {
  //Define the source
  source = "./talos-config" 

  //Add the control nodes to the module allowing talos to then use these
  control_nodes = module.kubernetes.control_nodes 

  //Add the worker nodes to the module allowing talos to then use these
  worker_nodes = module.kubernetes.worker_nodes 

  //Cluster vip(virtual ip address)
  cluster_vip = "Some ip on your lan that isn't used"

  //Add the dependency on 
  depends_on = [
    module.proxmox
  ]
}
```

### Creating the talos module variables
Within the `/talos-config` folder create a `variables.tf` file. Here we will reference the control-nodes and worker-nodes so Terraform can use the ip's to apply the talos configuration.

This is done by adding this to the `variables.tf` file
``` c#
//Control node variable allowing terraform to apply the config to the control nodes
variable "control_nodes" {
  type = map(object({
    target_node = string
    mac_address = string
    ip_address  = string
  }))
}

//Worker node variable allowing terraform to apply the config to the worker nodes. These are gotten by using the proxmox qemu guest agent so make sure the talos image you are using has this added as a extention.
variable "worker_nodes" {
  type = map(object({
    ip_addresses = list(list(string))
  }))
}

//Cluster VIP handels all kube-ctl traffic
variable "cluster_vip" {
  type = string
}
```

### Creating the talos cluster configuration
All work will be done in a `main.tf` file living in the `/talos-config` folder

#### Adding in the terraform provider
Adding in the terraform provider make sure to use the same version as used before in the `main.tf` file in the main directory
``` c#
terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "Your talos provider version"
    }
  }
}
```

#### Setting up local variables
The configuration for talos requires a few variables deined as

``` c#
locals {
  cluster_name     = "Homelab" //Set this to whatever you want your Talos cluster to be called
  cluster_endpoint = "https://${var.cluster_vip}:6443"

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
```

#### Talos secrets
Next up we need to generate the talos secrets this is done very simply by adding this to the `main.tf` file

``` c#
resource "talos_machine_secrets" "this" {} //Generates the talos machine secrets
```

#### Configuring the controlplane nodes
Next we define the configuration for the control nodes

``` c#
data "talos_machine_configuration" "controlplane" {
  cluster_name     = local.cluster_name //Cluster name
  cluster_endpoint = local.cluster_endpoint //cluster endpoint

  machine_type = "controlplane" //Sets the machine type to controlplane

  machine_secrets = talos_machine_secrets.this.machine_secrets

  talos_version = "Your talos version"

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda" //Specify installation disk
          image = "Your talos image link from the talos image factory"
          //When using proxmox you should use no-cloud with qemu guest agent installed
        }
      //Create a network interface to advertise the VIP
        network = {
          interfaces = [
            {
              deviceSelector = {
                physical = true
              }

              dhcp = true

              vip = {
                ip = var.cluster_vip
              }
            }
          ]
        }
      }
    })
  ]
}
```

#### Apply controlplane configration to controlplane nodes
Next up we apply the configuration to the controlnodes

``` c#
resource "talos_machine_configuration_apply" "controlplane" {
  for_each = var.control_nodes //Apply's the configuration to all control nodes
  node     = each.value.ip_address

  client_configuration = talos_machine_secrets.this.client_configuration

  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
}
``` 

#### Initilizing kubernets
Next up we initilize kubernetes by bootstrapping it.

``` c#
resource "talos_machine_bootstrap" "this" {
    node = var.control_nodes["Any one of your control nodes"].ip_address

    client_configuration = talos_machine_secrets.this.client_configuration

    depends_on = [
        talos_machine_configuration_apply.controlplane
    ]
}
```

#### Retreving the kubeconfig
Next we retrieve the kube config

``` c#
resource "talos_cluster_kubeconfig" "this" {
  node = var.control_nodes["cp-01"].ip_address

  client_configuration = talos_machine_secrets.this.client_configuration

  depends_on = [
    talos_machine_bootstrap.this
  ]
}
```

#### Configuring the workerplane nodes
Next up we configure the worker nodes which is done very similairly to the control nodes

``` c#
data "talos_machine_configuration" "worker" {
  cluster_name     = local.cluster_name //Cluster name
  cluster_endpoint = local.cluster_endpoint //cluster endpoint

  machine_type = "worker" //Sets the machine type to workerplane

  machine_secrets = talos_machine_secrets.this.machine_secrets

  talos_version = "Your talos version"

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda" //Specify installation disk
          image = "Your talos image link from the talos image factory"
          //When using proxmox you should use no-cloud with qemu guest agent installed
        }
      }
    })
  ]
}
```

#### Apply the configuration to your worker nodes
Up last we apply the configuratio to the worker nodes

``` c#
resource "talos_machine_configuration_apply" "worker" {
  for_each = var.worker_nodes

  node = local.worker_ips[each.key]

  client_configuration = talos_machine_secrets.this.client_configuration

  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration

  depends_on = [
    talos_machine_bootstrap.this
  ]
}
```

After running these command `terraform init`, `terraform validate`, `terraform plan` and `terraform apply` you should be left with a functioning Talos cluster 