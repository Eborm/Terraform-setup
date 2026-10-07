resource "kubernetes_namespace_v1" "traefik" {
  metadata {
    name = "traefik"
  }
}

resource "helm_release" "traefik_certificate" {
  name = "traefik-certificate"

  chart = "${path.module}/config-chart"

  namespace = kubernetes_namespace_v1.traefik.metadata[0].name

  create_namespace = false

  wait    = true
  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      domain     = var.domain
      issuerName = var.certificate_issuer
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.traefik
  ]
}

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.traefik_version

  namespace = kubernetes_namespace_v1.traefik.metadata[0].name

  create_namespace = false

  wait    = true
  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      deployment = {
        replicas = 2
      }

      ingressClass = {
        enabled        = true
        isDefaultClass = true
      }

      providers = {
        kubernetesCRD = {
          enabled                      = true
          allowCrossNamespace          = false
          safeNaming                   = true
          defaultTLSResourcesNamespace = "traefik"
        }

        kubernetesIngress = {
          enabled = true
        }

        kubernetesGateway = {
          enabled = false
        }
      }

      gatewayClass = {
        enabled = false
      }

      api = {
        dashboard = false
        insecure  = false
      }

      service = {
        enabled = true

        annotations = {
          "metallb.io/loadBalancerIPs" = var.ingress_ip
        }

        spec = {
          type                  = "LoadBalancer"
          externalTrafficPolicy = "Local"
        }
      }

      ports = {
        web = {
          port = 8000

          expose = {
            default = true
          }

          exposedPort = 80

          http = {
            aliasHeadersStrategy = "delete"

            middlewares = [
              "cloudflare-only@kubernetescrd"
            ]

            redirections = {
              entryPoint = {
                to        = "websecure"
                scheme    = "https"
                permanent = true
              }
            }
          }
        }

        websecure = {
          port = 8443

          expose = {
            default = true
          }

          exposedPort = 443

          http = {
            aliasHeadersStrategy = "delete"

            middlewares = [
              "cloudflare-only@kubernetescrd"
            ]

            tls = {
              enabled = true
            }
          }
        }
      }

      tlsStore = {
        default = {
          defaultCertificate = {
            secretName = "bramwesel-me-tls"
          }
        }
      }

      global = {
        sendAnonymousUsage = false
      }

      topologySpreadConstraints = [
        {
          maxSkew           = 1
          topologyKey       = "kubernetes.io/hostname"
          whenUnsatisfiable = "ScheduleAnyway"

          labelSelector = {
            matchLabels = {
              "app.kubernetes.io/name" = "traefik"
            }
          }
        }
      ]
      extraObjects = [{
        apiVersion = "traefik.io/v1alpha1"
        kind       = "Middleware"

        metadata = {
          name      = "cloudflare-only"
          namespace = "{{ .Release.Namespace }}"
        }

        spec = {
          ipAllowList = {
            sourceRange = [
              # Cloudflare IPv4
              "103.21.244.0/22",
              "103.22.200.0/22",
              "103.31.4.0/22",
              "104.16.0.0/13",
              "104.24.0.0/14",
              "108.162.192.0/18",
              "131.0.72.0/22",
              "141.101.64.0/18",
              "162.158.0.0/15",
              "172.64.0.0/13",
              "173.245.48.0/20",
              "188.114.96.0/20",
              "190.93.240.0/20",
              "197.234.240.0/22",
              "198.41.128.0/17",

              # Cloudflare IPv6
              "2400:cb00::/32",
              "2606:4700::/32",
              "2803:f800::/32",
              "2405:b500::/32",
              "2405:8100::/32",
              "2a06:98c0::/29",
              "2c0f:f248::/32"
            ]

            rejectStatusCode = 403
          }
        }
      }]
    })
  ]

  depends_on = [
    helm_release.traefik_certificate
  ]
}