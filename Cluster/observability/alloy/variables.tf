
variable "namespace" {
  description = "Kubernetes namespace for Alloy"
  type        = string
}

variable "chart_version" {
  description = "Grafana Community Alloy Helm chart version"
  type        = string
  default     = "1.15.0"
}
