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

variable "insecure_skip_tls" {
  description = "Disable TrueNAS API TLS certificate verification. Use only for explicitly trusted self-signed certificates."
  type        = bool
  default     = false
}

variable "ca_bundle" {
  description = "PEM-encoded CA certificate used to validate the TrueNAS API certificate."
  type        = string
  default     = ""
}

variable "postrender_runtime" {
  description = "Executable used for the Helm post-renderer: bash on WSL/Linux or pwsh on native Windows."
  type        = string
  default     = "bash"

  validation {
    condition     = contains(["bash", "pwsh"], var.postrender_runtime)
    error_message = "postrender_runtime must be either bash or pwsh."
  }
}

variable "chart_version" {
  description = "TrueNAS CSI Helm chart version."
  type        = string
  default     = "1.3.0"
}
