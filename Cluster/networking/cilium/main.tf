resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium_version

  namespace = "kube-system"

  wait    = true
  timeout = 600

  values = [
    yamlencode({
      # Talos assigns PodCIDRs to Kubernetes Nodes.
      ipam = {
        mode = "kubernetes"
      }

      # Cilium replaces kube-proxy.
      kubeProxyReplacement = true

      # Talos KubePrism.
      k8sServiceHost = "localhost"
      k8sServicePort = 7445

      # Talos already provides cgroup v2.
      cgroup = {
        autoMount = {
          enabled = false
        }

        hostRoot = "/sys/fs/cgroup"
      }

      # Talos does not allow SYS_MODULE.
      securityContext = {
        capabilities = {
          ciliumAgent = [
            "CHOWN",
            "KILL",
            "NET_ADMIN",
            "NET_RAW",
            "IPC_LOCK",
            "SYS_ADMIN",
            "SYS_RESOURCE",
            "DAC_OVERRIDE",
            "FOWNER",
            "SETGID",
            "SETUID",
          ]

          cleanCiliumState = [
            "NET_ADMIN",
            "SYS_ADMIN",
            "SYS_RESOURCE",
          ]
        }
      }

      # Talos 1.8+ DNS forwarding and Cilium eBPF host routing
      # have a compatibility issue without this setting.
      bpf = {
        hostLegacyRouting = true
      }

      operator = {
        replicas = 2
      }

      # We're using Traefik for ingress, not Cilium's Envoy/Ingress.
      envoy = {
        enabled = false
      }

      # We'll enable Hubble after the base dataplane is confirmed healthy.
      hubble = {
        enabled = false
      }
    })
  ]
}