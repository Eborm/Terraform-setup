variable "truenas_host" {
  description = "TrueNAS IP address or hostname."
  type        = string
  default     = "192.168.68.148"
}

variable "truenas_pool" {
  description = "ZFS pool used for Kubernetes volumes."
  type        = string
  default     = "Storage"
}

variable "truenas_api_key" {
  description = "API key for the dedicated TrueNAS Kubernetes CSI user."
  type        = string
  sensitive   = true
}

variable "chart_version" {
  description = "TrueNAS CSI Helm chart version."
  type        = string
  default     = "1.3.0"
}
