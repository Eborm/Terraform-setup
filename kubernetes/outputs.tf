output "control_nodes" {
  value = local.talos_control_node
}

output "worker_vms" {
  value = proxmox_virtual_environment_vm.Worker_node
}

output "worker_nodes" {
  value = {
    for name, vm in proxmox_virtual_environment_vm.Worker_node : name => {
      ip_addresses = vm.ipv4_addresses
    }
  }
}