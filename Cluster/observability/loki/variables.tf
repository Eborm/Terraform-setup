
variable "namespace" {
  description = "Kubernetes namespace for Loki"
  type        = string
}

variable "chart_version" {
  description = "Grafana Community Loki Helm chart version"
  type        = string
  default     = "21.2.1"
}

variable "storage_class_name" {
  description = "Storage class used for Loki persistence"
  type        = string
  default     = "truenas-nfs-loki"
}

variable "storage_size" {
  description = "Size of Loki's persistent volume"
  type        = string
  default     = "10Gi"
}

variable "retention_period" {
  description = "How long Loki retains logs"
  type        = string
  default     = "168h"
}
