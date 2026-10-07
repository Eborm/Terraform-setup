variable "hostname" {
  description = "Hostname used by the test application."
  type        = string
  default     = "test.bramwesel.me"
}

variable "namespace" {
  description = "Namespace for the test application."
  type        = string
  default     = "demo"
}

variable "image" {
  description = "Container image for the test application."
  type        = string
  default     = "traefik/whoami:v1.10.3"
}