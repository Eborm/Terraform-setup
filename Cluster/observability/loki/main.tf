
resource "helm_release" "loki" {
  name       = "loki"
  namespace  = var.namespace
  repository = "https://grafana-community.github.io/helm-charts"
  chart      = "loki"
  version    = var.chart_version

  atomic  = true
  timeout = 600
  wait    = true

  values = [
    yamlencode({
      deploymentMode   = "Monolithic"
      fullnameOverride = "loki"

      singleBinary = {
        enabled  = true
        replicas = 1

        persistence = {
          enabled      = true
          storageClass = var.storage_class_name
          size         = var.storage_size
          accessModes  = ["ReadWriteOnce"]
          whenDeleted  = "Retain"
          whenScaled   = "Retain"
        }

        podSecurityContext = {
          fsGroup             = 10001
          fsGroupChangePolicy = "OnRootMismatch"
          runAsGroup          = 10001
          runAsNonRoot        = true
          runAsUser           = 10001

          seccompProfile = {
            type = "RuntimeDefault"
          }
        }
      }

      # Disable the separate gateway; Alloy and Grafana
      # communicate directly with the Loki service.
      gateway = {
        enabled = false
      }

      # Disable separate read/write/backend components.
      read = {
        replicas = 0
      }

      write = {
        replicas = 0
      }

      backend = {
        replicas = 0
      }

      # The compactor runs inside the Monolithic Loki process.
      compactor = {
        enabled = false
      }

      loki = {
        auth_enabled = false

        commonConfig = {
          replication_factor = 1
          path_prefix        = "/var/loki"
        }

        schemaConfig = {
          configs = [
            {
              from         = "2024-04-01"
              store        = "tsdb"
              object_store = "filesystem"
              schema       = "v13"

              index = {
                prefix = "index_"
                period = "24h"
              }
            }
          ]
        }

        storage = {
          type = "filesystem"

          filesystem = {
            chunks_directory = "/var/loki/chunks"
            rules_directory  = "/var/loki/rules"
          }
        }

        limits_config = {
          retention_period = var.retention_period
        }

        compactor = {
          working_directory      = "/var/loki/compactor"
          compaction_interval    = "10m"
          retention_enabled      = true
          delete_request_store   = "filesystem"
          retention_delete_delay = "2h"
        }
      }

      test = {
        enabled = false
      }

      lokiCanary = {
        enabled = false
      }
    })
  ]
}
