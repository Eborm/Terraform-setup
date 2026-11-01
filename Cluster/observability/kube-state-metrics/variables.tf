variable "namespace" {
  description = "Namespace where kube-state-metrics runs"
  type        = string
}

variable "chart_version" {
  description = "Pinned kube-state-metrics Helm chart version"
  type        = string
  default     = "8.6.0"
}