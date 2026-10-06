data "kubernetes_namespace_v1" "kube_system" {
  metadata {
    name = "kube-system"
  }
}

output "kube_system_namespace" {
  value = data.kubernetes_namespace_v1.kube_system.metadata[0].name
}