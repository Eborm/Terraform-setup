output "kubeconfig" {
  value     = module.talos-config.kubeconfig
  sensitive = true
}