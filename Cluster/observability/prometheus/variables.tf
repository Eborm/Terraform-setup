variable "namespace" {
  description = "Existing namespace for Prometheus"
  type        = string
}

variable "retention" {
  description = "How long Prometheus retains metrics"
  type        = string
  default     = "7d"
}

variable "retention_size" {
  description = "Maximum Prometheus TSDB size"
  type        = string
  default     = "8GB"
}