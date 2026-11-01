variable "namespace" {
  description = "Existing namespace for Alertmanager"
  type        = string
}

variable "replicas" {
  description = "Number of Alertmanager replicas"
  type        = number
  default     = 1
}

variable "retention" {
  description = "How long Alertmanager retains notification and silence state"
  type        = string
  default     = "120h"
}