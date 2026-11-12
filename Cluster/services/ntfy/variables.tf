variable "hostname" {
  description = "External hostname used for ntfy."
  type        = string
}

variable "ntfy_client_password_hash" {
  description = "Bcrypt password hash for the ntfy client account."
  type        = string
  sensitive   = true
}

variable "ntfy_alertmanager_password_hash" {
  description = "Bcrypt password hash for the Alertmanager account."
  type        = string
  sensitive   = true
}

variable "ntfy_alertmanager_token" {
  description = "Access token used by Alertmanager to publish notifications."
  type        = string
  sensitive   = true

  validation {
    condition = (
      startswith(var.ntfy_alertmanager_token, "tk_") &&
      length(var.ntfy_alertmanager_token) == 32
    )
    error_message = "The ntfy Alertmanager token must start with tk_ and contain 32 characters in total."
  }
}

variable "storage_class_name" {
  description = "StorageClass used for ntfy persistent storage."
  type        = string
  default     = "truenas-nfs"
}

variable "storage_size" {
  description = "Size of ntfy persistent storage."
  type        = string
  default     = "2Gi"
}

variable "run_as_user" {
  description = "UID used by the ntfy container."
  type        = number
  default     = 1000
}

variable "run_as_group" {
  description = "GID used by the ntfy container."
  type        = number
  default     = 1000
}