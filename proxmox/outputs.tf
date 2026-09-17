//Ouput the control nodes so that terraform can reuse these to join them into the cluster
output "control_nodes" {
  value = local.talos_control_node
}

// Export the ip's of the worker nodes so that terrafrom can use them to join the
output "worker_nodes" {
  value = {
    for name, vm in proxmox_virtual_environment_vm.Worker_node : name => {
      ip_addresses = vm.ipv4_addresses
    }
  }
}