terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
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