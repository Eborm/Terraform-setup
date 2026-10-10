variable "crowdsec_version" {
  description = "CrowdSec Helm chart version."
  type        = string
  default     = "0.24.2"
}

variable "namespace" {
  description = "Namespace for CrowdSec."
  type        = string
  default     = "crowdsec"
}

variable "storage_class_name" {
  description = "StorageClass used for CrowdSec persistent storage."
  type        = string
  default     = "truenas-nfs"
}

variable "data_size" {
  description = "Persistent size for CrowdSec data."
  type        = string
  default     = "1Gi"
}

variable "config_size" {
  description = "Persistent size for CrowdSec configuration."
  type        = string
  default     = "100Mi"
}

variable "crowdsec_bouncer_key" {
  description = "Shared key for the Traefik bouncer."
  type        = string
  sensitive   = true
}