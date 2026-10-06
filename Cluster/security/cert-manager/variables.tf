variable "cert_manager_version" {
  type    = string
  default = "1.21.2"
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_zone" {
  type = string
}

variable "acme_email" {
  type = string
}