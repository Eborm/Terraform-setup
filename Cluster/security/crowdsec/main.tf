resource "kubernetes_namespace_v1" "crowdsec" {
  metadata {
    name = var.namespace

    labels = {
      # The CrowdSec agent reads host /var/log through hostPath.
      # Kubernetes Pod Security therefore needs this namespace to
      # allow the host-level access required by the agent.
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

resource "helm_release" "crowdsec" {
  name = "crowdsec"

  repository = "https://crowdsecurity.github.io/helm-charts"
  chart      = "crowdsec"
  version    = var.crowdsec_version

  namespace = kubernetes_namespace_v1.crowdsec.metadata[0].name

  create_namespace = false

  wait    = true
  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      # Talos uses containerd.
      # CrowdSec's Kubernetes documentation specifically calls this
      # out for Kubernetes container logs.
      container_runtime = "containerd"

      lapi = {
        env = [
          {
            name = "BOUNCER_KEY_traefik"

            valueFrom = {
              secretKeyRef = {
                name = kubernetes_secret_v1.bouncer_key.metadata[0].name
                key  = "BOUNCER_KEY_traefik"
              }
            }
          }
        ]


        enabled  = true
        replicas = 1

        persistentVolume = {
          data = {
            enabled          = true
            accessModes      = ["ReadWriteOnce"]
            storageClassName = var.storage_class_name
            size             = var.data_size
          }

          config = {
            enabled          = true
            accessModes      = ["ReadWriteOnce"]
            storageClassName = var.storage_class_name
            size             = var.config_size
          }
        }

        service = {
          type = "ClusterIP"
        }

        metrics = {
          enabled = true

          serviceMonitor = {
            enabled = false
          }

          podMonitor = {
            enabled = false
          }
        }
      }

      agent = {
        enabled      = true
        isDeployment = false

        # Read logs from Traefik pods.
        acquisition = [
          {
            namespace = "traefik"
            podName   = "traefik-*"
            program   = "traefik"
          }
        ]

        env = [
          {
            name  = "COLLECTIONS"
            value = "crowdsecurity/traefik"
          }
        ]

        # The agent needs host /var/log to read Kubernetes container logs.
        hostVarLog = true

        metrics = {
          enabled = true

          serviceMonitor = {
            enabled = false
          }

          podMonitor = {
            enabled = false
          }
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.crowdsec,
    kubernetes_secret_v1.bouncer_key
  ]
}

resource "kubernetes_secret_v1" "bouncer_key" {
  metadata {
    name      = "crowdsec-keys"
    namespace = kubernetes_namespace_v1.crowdsec.metadata[0].name
  }

  type = "Opaque"

  data_wo = {
    "BOUNCER_KEY_traefik" = var.crowdsec_bouncer_key
  }

  data_wo_revision = parseint(substr(sha256(var.crowdsec_bouncer_key), 0, 8), 16)
}