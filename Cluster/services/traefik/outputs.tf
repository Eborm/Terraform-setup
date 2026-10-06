output "ingress_ip" {
  value = var.ingress_ip
}

output "namespace" {
  value = kubernetes_namespace_v1.traefik.metadata[0].name
}