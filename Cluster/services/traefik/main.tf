
locals {
  cloudflare_ip_ranges = [
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
}

resource "kubernetes_namespace_v1" "traefik" {
  metadata {
    name = "traefik"
  }
}

resource "helm_release" "traefik_certificate" {
  name  = "traefik-certificate"
  chart = "${path.module}/config-chart"

  namespace        = kubernetes_namespace_v1.traefik.metadata[0].name
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

  namespace        = kubernetes_namespace_v1.traefik.metadata[0].name
  create_namespace = false

  wait    = true
  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      deployment = {
        replicas = 2

        additionalVolumes = [
          {
            name     = "plugins-storage"
            emptyDir = {}
          }
        ]
      }

      ingressClass = {
        enabled        = true
        isDefaultClass = true
      }

      # Traefik's access logs are consumed by the CrowdSec agents.
      accessLog = {
        enabled = true
        format  = "json"

        fields = {
          defaultMode = "keep"

          headers = {
            defaultMode = "drop"

            names = {
              User-Agent   = "keep"
              Content-Type = "keep"
            }
          }
        }
      }

      # Load the CrowdSec bouncer plugin.
      experimental = {
        plugins = {
          bouncer = {
            moduleName = "github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin"
            version    = "v1.4.5"
          }
          coraza = {
            moduleName = "github.com/jcchavezs/coraza-http-wasm-traefik"
            version    = "v0.3.0"
          }
        }
      }

      # Mount the key from the Kubernetes Secret as a file.
      volumes = [
        {
          name       = "crowdsec-bouncer-key"
          mountPath  = "/etc/traefik/crowdsec"
          type       = "secret"
          secretName = kubernetes_secret_v1.crowdsec_bouncer_key.metadata[0].name
          additionalVolumeMounts = [
            {
              name      = "plugins-storage"
              mountPath = "/plugins-storage"
            }
          ]
        }
      ]

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

          # Only trust forwarded headers from Cloudflare proxy addresses.
          forwardedHeaders = {
            trustedIPs = local.cloudflare_ip_ranges
          }

          http = {
            aliasHeadersStrategy = "delete"

            middlewares = [
              "traefik_cloudflare-only@kubernetescrd"
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

          forwardedHeaders = {
            trustedIPs = local.cloudflare_ip_ranges
          }

          http = {
            aliasHeadersStrategy = "delete"

            # Apply Cloudflare filtering first, then CrowdSec decisions.
            middlewares = [
              "traefik_cloudflare-only@kubernetescrd",
              "traefik_crowdsec-bouncer@kubernetescrd"
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

      # Traefik CRDs are installed by this Helm chart.
      # These objects therefore belong in this release, not the
      # earlier certificate config-chart release.
      extraObjects = [
        {
          apiVersion = "traefik.io/v1alpha1"
          kind       = "Middleware"

          metadata = {
            name      = "cloudflare-only"
            namespace = "{{ .Release.Namespace }}"
          }

          spec = {
            ipAllowList = {
              sourceRange      = local.cloudflare_ip_ranges
              rejectStatusCode = 403
            }
          }
        },

        {
          apiVersion = "traefik.io/v1alpha1"
          kind       = "Middleware"

          metadata = {
            name      = "crowdsec-bouncer"
            namespace = "{{ .Release.Namespace }}"
          }

          spec = {
            plugin = {
              bouncer = {
                enabled             = true
                crowdsecMode        = "stream"
                crowdsecLapiScheme  = "http"
                crowdsecLapiHost    = "crowdsec-service.crowdsec.svc.cluster.local:8080"
                crowdsecLapiPath    = "/"
                crowdsecLapiKeyFile = "/etc/traefik/crowdsec/BOUNCER_KEY_traefik"

                # Trust X-Forwarded-For only when the proxy is Cloudflare.
                forwardedHeadersTrustedIps = local.cloudflare_ip_ranges
              }
            }
          }
        },

        {
          apiVersion = "traefik.io/v1alpha1"
          kind       = "ServersTransport"

          metadata = {
            name      = "truenas"
            namespace = "{{ .Release.Namespace }}"
          }

          spec = {
            serverName = var.truenas_hostname

            # Use the current rootCAs syntax instead of deprecated
            # rootCAsSecrets.
            rootCAs = var.truenas_ca_bundle != "" ? [
              {
                secret = kubernetes_secret_v1.truenas_ca[0].metadata[0].name
              }
            ] : []

            insecureSkipVerify = var.truenas_ca_bundle == ""
          }
        },

        {
          apiVersion = "traefik.io/v1alpha1"
          kind       = "IngressRoute"

          metadata = {
            name      = "truenas"
            namespace = "{{ .Release.Namespace }}"
          }

          spec = {
            entryPoints = [
              "websecure"
            ]

            routes = [
              {
                match = "Host(`${var.truenas_hostname}`)"
                kind  = "Rule"

                services = [
                  {
                    name             = kubernetes_service_v1.truenas.metadata[0].name
                    port             = 443
                    scheme           = "https"
                    serversTransport = "truenas"
                  }
                ]
              }
            ]

            tls = {}
          }
        }
      ]
    })
  ]

  depends_on = [
    helm_release.traefik_certificate,
    kubernetes_secret_v1.truenas_ca,
    kubernetes_service_v1.truenas,
    kubernetes_endpoints_v1.truenas,
    kubernetes_secret_v1.crowdsec_bouncer_key,
    kubernetes_namespace_v1.traefik
  ]
}

resource "kubernetes_secret_v1" "truenas_ca" {
  count = 1

  metadata {
    name      = "truenas-ca"
    namespace = kubernetes_namespace_v1.traefik.metadata[0].name
  }

  type = "Opaque"

  data = {
    "ca.crt" = var.truenas_ca_bundle
  }
}

resource "kubernetes_service_v1" "truenas" {
  metadata {
    name      = "truenas"
    namespace = kubernetes_namespace_v1.traefik.metadata[0].name
  }

  spec {
    port {
      name        = "https"
      port        = 443
      target_port = 443
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_endpoints_v1" "truenas" {
  metadata {
    name      = kubernetes_service_v1.truenas.metadata[0].name
    namespace = kubernetes_namespace_v1.traefik.metadata[0].name
  }

  subset {
    address {
      ip = var.truenas_host
    }

    port {
      name     = "https"
      port     = 443
      protocol = "TCP"
    }
  }
}

resource "kubernetes_secret_v1" "crowdsec_bouncer_key" {
  metadata {
    name      = "crowdsec-bouncer-key"
    namespace = kubernetes_namespace_v1.traefik.metadata[0].name
  }

  type = "Opaque"

  data_wo = {
    "BOUNCER_KEY_traefik" = var.crowdsec_bouncer_key
  }

  data_wo_revision = parseint(substr(sha256(var.crowdsec_bouncer_key), 0, 8), 16)
}