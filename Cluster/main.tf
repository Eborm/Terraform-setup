terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }

    time = {
      source  = "hashicorp/time"
      version = "0.14.2"
    }
  }
}

locals {
  kubeconfig = yamldecode(
    file(var.kubeconfig_path)
  )
}

provider "kubernetes" {
  host = local.kubeconfig.clusters[0].cluster.server

  cluster_ca_certificate = base64decode(
    local.kubeconfig.clusters[0].cluster["certificate-authority-data"]
  )

  client_certificate = base64decode(
    local.kubeconfig.users[0].user["client-certificate-data"]
  )

  client_key = base64decode(
    local.kubeconfig.users[0].user["client-key-data"]
  )
}

provider "helm" {
  kubernetes = {
    host = local.kubeconfig.clusters[0].cluster.server

    cluster_ca_certificate = base64decode(
      local.kubeconfig.clusters[0].cluster["certificate-authority-data"]
    )

    client_certificate = base64decode(
      local.kubeconfig.users[0].user["client-certificate-data"]
    )

    client_key = base64decode(
      local.kubeconfig.users[0].user["client-key-data"]
    )
  }
}

module "cilium" {
  source = "./networking/cilium"
}

module "metallb" {
  source = "./networking/metallb"

  depends_on = [
    module.cilium
  ]
}

module "cert_manager" {
  source = "./security/cert-manager"

  cert_manager_version = "1.21.2"
  kubeconfig_path      = var.kubeconfig_path

  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone      = var.cloudflare_zone
  acme_email           = var.acme_email
}

module "traefik" {
  source = "./services/traefik"

  ingress_ip = "192.168.68.190"
  domain     = "bramwesel.me"

  depends_on = [
    module.metallb,
    module.cert_manager
  ]
}