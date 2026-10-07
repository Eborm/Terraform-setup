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
  timeout = 1200

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
    })
  ]

  depends_on = [
    helm_release.traefik_certificate
  ]
}