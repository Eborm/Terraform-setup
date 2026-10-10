variable "traefik_version" {
  type    = string
  default = "41.6.0"
}

variable "ingress_ip" {
  type    = string
  default = "192.168.68.190"
}

variable "domain" {
  type    = string
  default = "bramwesel.me"
}

variable "certificate_issuer" {
  description = "ClusterIssuer used for the Traefik certificate."
  type        = string
  default     = "letsencrypt-production"
}

variable "truenas_host" {
  description = "TrueNAS IP address or hostname used by Traefik."
  type        = string
  default     = "192.168.68.148"
}

variable "truenas_hostname" {
  description = "Hostname exposed by Traefik for TrueNAS."
  type        = string
  default     = "truenas.bramwesel.me"
}

variable "truenas_ca_bundle" {
  description = "PEM-encoded CA certificate used to validate the TrueNAS HTTPS certificate."
  type        = string
  sensitive   = true

  validation {
    condition     = trimspace(var.truenas_ca_bundle) != ""
    error_message = "truenas_ca_bundle must contain the CA certificate used to validate the TrueNAS HTTPS certificate."
  }
}

variable "crowdsec_bouncer_key" {
  description = "Shared key for the CrowdSec Traefik bouncer."
  type        = string
  sensitive   = true
}