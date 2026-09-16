variable "control_nodes" {
  type = map(object({
    target_node = string
    mac_address = string
    ip_address  = string
  }))
}

variable "worker_nodes" {
  type = map(object({
    ip_addresses = list(list(string))
  }))
}