
locals {
  grafana_alerting_provisioning = yamlencode({
    apiVersion = 1

    contactPoints = [
      {
        orgId = 1
        name  = "Loki Alertmanager"

        receivers = [
          {
            uid  = "loki-alertmanager"
            type = "prometheus-alertmanager"

            settings = {
              url = "http://alertmanager-main.monitoring.svc.cluster.local:9093"
            }
          }
        ]
      }
    ]

    groups = [
      {
        orgId    = 1
        name     = "loki-high-volume"
        folder   = "Kubernetes"
        interval = "1m"

        rules = [
          {
            uid       = "loki-high-log-volume"
            title     = "High Log Volume"
            condition = "C"

            data = [
              {
                refId = "A"

                datasourceUid = "loki"

                relativeTimeRange = {
                  from = 60
                  to   = 0
                }

                model = {
                  datasource = {
                    type = "loki"
                    uid  = "loki"
                  }

                  editorMode    = "code"
                  expr          = "sum by (namespace, pod, container) (count_over_time({namespace=~\".+\", pod=~\".+\", container=~\".+\"}[1m]))"
                  instant       = true
                  queryType     = "instant"
                  intervalMs    = 1000
                  maxDataPoints = 43200
                  refId         = "A"
                }
              },
              {
                refId         = "B"
                datasourceUid = "__expr__"

                relativeTimeRange = {
                  from = 0
                  to   = 0
                }

                model = {
                  conditions = [
                    {
                      evaluator = {
                        params = []
                        type   = "gt"
                      }
                      operator = {
                        type = "and"
                      }
                      query = {
                        params = ["B"]
                      }
                      reducer = {
                        params = []
                        type   = "last"
                      }
                      type = "query"
                    }
                  ]

                  datasource = {
                    type = "__expr__"
                    uid  = "__expr__"
                  }

                  expression    = "A"
                  reducer       = "last"
                  settings      = { mode = "dropNN" }
                  intervalMs    = 1000
                  maxDataPoints = 43200
                  refId         = "B"
                  type          = "reduce"
                }
              },
              {
                refId         = "C"
                datasourceUid = "__expr__"

                relativeTimeRange = {
                  from = 0
                  to   = 0
                }

                model = {
                  conditions = [
                    {
                      evaluator = {
                        params = [100]
                        type   = "gt"
                      }
                      operator = {
                        type = "and"
                      }
                      query = {
                        params = ["C"]
                      }
                      reducer = {
                        params = []
                        type   = "last"
                      }
                      type = "query"
                    }
                  ]

                  datasource = {
                    type = "__expr__"
                    uid  = "__expr__"
                  }

                  expression    = "B"
                  intervalMs    = 1000
                  maxDataPoints = 43200
                  refId         = "C"
                  type          = "threshold"
                }
              }
            ]

            noDataState  = "OK"
            execErrState = "Error"
            for          = "5m"
            isPaused     = false

            labels = {
              severity = "warning"
              source   = "loki"
            }

            annotations = {
              summary     = "High log volume in {{ $labels.namespace }}/{{ $labels.pod }}/{{ $labels.container }}"
              description = "This container has exceeded 100 log lines per minute for at least 5 minutes. Current count: {{ $values.B.Value }}"
            }

            notification_settings = {
              receiver = "Loki Alertmanager"
            }
          }
        ]
      }
    ]
  })
}

resource "kubernetes_config_map_v1" "grafana_alerting" {
  metadata {
    name      = "grafana-alerting"
    namespace = var.namespace
  }

  data = {
    "loki-high-log-volume.yaml" = local.grafana_alerting_provisioning
  }
}
