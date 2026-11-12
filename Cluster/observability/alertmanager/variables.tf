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

variable "ntfy_url" {
  description = "ntfy webhook URL for Alertmanager notifications"
  type        = string
}

variable "ntfy_alertmanager_token" {
  description = "Access token used by Alertmanager to authenticate with ntfy"
  type        = string
  sensitive   = true
}