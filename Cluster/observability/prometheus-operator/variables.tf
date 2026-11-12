variable "namespace" {
  description = "Existing namespace for observability components"
  type        = string
}

variable "chart_version" {
  description = "Pinned kube-prometheus-stack chart version"
  type        = string
  default     = "92.11.0"
}