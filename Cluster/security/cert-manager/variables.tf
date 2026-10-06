variable "cert_manager_version" {
  type    = string
  default = "1.21.2"
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig used by the Cluster root."
  type        = string
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