variable "traefik_namespace" {
  description = "Namespace containing Traefik."
  type        = string
  default     = "traefik"
}

variable "middleware_name" {
  description = "Name of the Coraza Traefik Middleware."
  type        = string
  default     = "coraza-waf"
}

variable "engine_mode" {
  description = "Coraza engine mode. Use DetectionOnly while testing."
  type        = string
  default     = "DetectionOnly"

  validation {
    condition = contains(
      ["DetectionOnly", "On"],
      var.engine_mode
    )

    error_message = "engine_mode must be DetectionOnly or On."
  }
}