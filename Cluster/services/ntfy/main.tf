resource "kubernetes_namespace_v1" "ntfy" {
  metadata {
    name = "ntfy"

    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

resource "kubernetes_secret_v1" "ntfy_server_config" {
  metadata {
    name      = "ntfy-server-config"
    namespace = kubernetes_namespace_v1.ntfy.metadata[0].name
  }

  type = "Opaque"

  # Keep authentication configuration out of Terraform state.
  data_wo = {
    "server.yml" = yamlencode({
      "base-url"             = "https://${var.hostname}"
      "listen-http"          = ":8080"
      "behind-proxy"         = true
      "auth-file"            = "/var/lib/ntfy/user.db"
      "cache-file"           = "/var/lib/ntfy/cache.db"
      "cache-duration"       = "168h"
      "attachment-cache-dir" = "/var/lib/ntfy/attachments"
      "auth-default-access"  = "deny-all"

      "auth-users" = [
        "client:${var.ntfy_client_password_hash}:user",
        "alertmanager:${var.ntfy_alertmanager_password_hash}:user"
      ]

      "auth-access" = [
        "client:*:read-only",
        "alertmanager:alerts:write-only"
      ]

      "auth-tokens" = [
        "alertmanager:${var.ntfy_alertmanager_token}:alertmanager"
      ]
    })
  }

  # Changing any authentication input updates the Kubernetes Secret.
  data_wo_revision = parseint(
    substr(
      sha256(join(":", [
        var.ntfy_client_password_hash,
        var.ntfy_alertmanager_password_hash,
        var.ntfy_alertmanager_token
      ])),
      0,
      8
    ),
    16
  )
}

resource "kubernetes_persistent_volume_claim_v1" "ntfy_data" {
  metadata {
    name      = "ntfy-data"
    namespace = kubernetes_namespace_v1.ntfy.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteMany"]

    storage_class_name = var.storage_class_name

    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }
}

resource "kubernetes_deployment_v1" "ntfy" {
  metadata {
    name      = "ntfy"
    namespace = kubernetes_namespace_v1.ntfy.metadata[0].name

    labels = {
      "app.kubernetes.io/name" = "ntfy"
    }
  }

  spec {
    replicas = 1

    # Avoid overlapping instances accessing the SQLite databases.
    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "ntfy"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "ntfy"
        }
      }

      spec {
        automount_service_account_token  = false
        termination_grace_period_seconds = 30

        security_context {
          run_as_non_root = true
          run_as_user     = var.run_as_user
          run_as_group    = var.run_as_group

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = "ntfy"
          image = "binwiederhier/ntfy:v2.34.0"

          image_pull_policy = "IfNotPresent"

          args = ["serve"]

          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }

          env {
            name  = "TZ"
            value = "Europe/Amsterdam"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "128Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            run_as_user                = var.run_as_user
            run_as_group               = var.run_as_group

            capabilities {
              drop = ["ALL"]
            }
          }

          startup_probe {
            http_get {
              path = "/v1/health"
              port = 8080
            }

            period_seconds    = 5
            failure_threshold = 30
          }

          readiness_probe {
            http_get {
              path = "/v1/health"
              port = 8080
            }

            period_seconds    = 10
            timeout_seconds   = 3
            failure_threshold = 3
          }

          liveness_probe {
            http_get {
              path = "/v1/health"
              port = 8080
            }

            period_seconds        = 20
            timeout_seconds       = 3
            failure_threshold     = 3
            initial_delay_seconds = 20
          }

          volume_mount {
            name       = "ntfy-config"
            mount_path = "/etc/ntfy"
            read_only  = true
          }

          volume_mount {
            name       = "ntfy-data"
            mount_path = "/var/lib/ntfy"
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "ntfy-config"

          secret {
            secret_name = kubernetes_secret_v1.ntfy_server_config.metadata[0].name
          }
        }

        volume {
          name = "ntfy-data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.ntfy_data.metadata[0].name
          }
        }

        volume {
          name = "tmp"

          empty_dir {}
        }
      }
    }
  }

  depends_on = [
    kubernetes_secret_v1.ntfy_server_config,
    kubernetes_persistent_volume_claim_v1.ntfy_data
  ]
}

resource "kubernetes_service_v1" "ntfy" {
  metadata {
    name      = "ntfy"
    namespace = kubernetes_namespace_v1.ntfy.metadata[0].name
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name" = "ntfy"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_ingress_v1" "ntfy" {
  metadata {
    name      = "ntfy"
    namespace = kubernetes_namespace_v1.ntfy.metadata[0].name

    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls"         = "true"
    }
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = var.hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.ntfy.metadata[0].name

              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment_v1.ntfy
  ]
}