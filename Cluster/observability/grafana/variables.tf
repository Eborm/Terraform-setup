variable "namespace" {
  description = "Existing namespace where Grafana will run"
  type        = string
}

variable "hostname" {
  description = "External hostname for Grafana"
  type        = string
}

variable "chart_version" {
  description = "Pinned Grafana Helm chart version"
  type        = string
  default     = "13.2.8"
}

variable "admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 32
    error_message = "Grafana admin password must be at least 32 characters."
  }
}

variable "storage_class_name" {
  description = "StorageClass used for Grafana persistent storage"
  type        = string
  default     = "truenas-nfs"
}

variable "storage_size" {
  description = "Size of Grafana persistent storage"
  type        = string
  default     = "5Gi"
}