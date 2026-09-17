// Export the control node ip's so that terraform can use these to link them all together in the cluster
variable "control_nodes" {
  type = map(object({
    target_node = string
    mac_address = string
    ip_address  = string
  }))
}

//Export the ip's of the worker nodes so that terraform can use these to put them into the cluster
variable "worker_nodes" {
  type = map(object({
    ip_addresses = list(list(string))
  }))
}