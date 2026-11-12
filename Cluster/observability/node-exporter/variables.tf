variable "namespace" {
  description = "Namespace where Node Exporter runs"
  type        = string
}

variable "chart_version" {
  description = "Pinned Prometheus Node Exporter Helm chart version"
  type        = string
  default     = "4.59.0"
}