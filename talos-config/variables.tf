//Map the control-nodes variables given in main.tf so the variables are usable in /talos-config/main.tf
variable "control_nodes" {
  type = map(object({
    target_node = string
    mac_address = string
    ip_address  = string
  }))
}

//Map the worker-nodes variables given in main.tf so the variables are usable in /talos-config/main.tf
variable "worker_nodes" {
  type = map(object({
    ip_addresses = list(list(string))
  }))
}