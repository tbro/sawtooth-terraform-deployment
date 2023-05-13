resource "kubernetes_namespace" "metrics" {
  metadata {
    name = "metrics"
  }
}

resource "kubernetes_secret" "docker-registry-metrics" {
  metadata {
    name = "docker-registry"
    namespace = "metrics"
  }

  data = {
    ".dockerconfigjson" = "${file("${var.docker-config-file}")}"
  }

  type = "kubernetes.io/dockerconfigjson"
}

resource "kubernetes_stateful_set" "influxdb" {
  metadata {
    name      = "influxdb"
    namespace = "metrics"

    labels = {
      app = "influxdb"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "influxdb"
      }
    }

    template {
      metadata {
        labels = {
          app = "influxdb"
        }
      }

      spec {
        container {
          name  = "influxdb"
          image = "influxdb:1.8"

          port {
            name           = "influxdb"
            container_port = 8086
          }

          env {
            name  = "INFLUXDB_DB"
            value = "metrics"
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/influxdb"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name      = "data"
        namespace = "metrics"
      }

      spec {
        access_modes = ["ReadWriteOnce"]

        resources {
          requests = {
            storage = "10G"
          }
        }
      }
    }

    service_name = "influxdb"
  }
}

resource "kubernetes_service" "influxdb" {
  metadata {
    name      = "influxdb"
    namespace = "metrics"
  }

  spec {
    port {
      name        = "influxdb"
      port        = 8086
      target_port = "8086"
    }

    selector = {
      app = "influxdb"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_persistent_volume_claim" "grafana_pvc" {
  metadata {
    name      = "grafana-pvc"
    namespace = "metrics"
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "grafana" {
  metadata {
    name      = "grafana"
    namespace = "metrics"

    labels = {
      app = "grafana"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "grafana"
      }
    }

    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }

      spec {
        volume {
          name = "grafana-pv"

          persistent_volume_claim {
            claim_name = "grafana-pvc"
          }
        }

        container {
          name  = "grafana"
          image = "registry.gitlab.com/vidaloop/votingapp/package-registry/sawtooth-stats-grafana:5"

          port {
            name           = "http-grafana"
            container_port = 3000
            protocol       = "TCP"
          }

          resources {
            requests = {
              cpu = "250m"

              memory = "750Mi"
            }
          }

          volume_mount {
            name       = "grafana-pv"
            mount_path = "/var/lib/grafana"
          }

          liveness_probe {
            tcp_socket {
              port = "3000"
            }

            initial_delay_seconds = 30
            timeout_seconds       = 1
            period_seconds        = 10
            success_threshold     = 1
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path   = "/robots.txt"
              port   = "3000"
              scheme = "HTTP"
            }

            initial_delay_seconds = 10
            timeout_seconds       = 2
            period_seconds        = 30
            success_threshold     = 1
            failure_threshold     = 3
          }

          image_pull_policy = "Always"
        }

        security_context {
          supplemental_groups = [0]
          fs_group            = 472
        }

        image_pull_secrets {
          name = "docker-registry"
        }
      }
    }
  }
}

resource "kubernetes_service" "grafana" {
  metadata {
    name      = "grafana"
    namespace = "metrics"
  }

  spec {
    port {
      protocol    = "TCP"
      port        = 80
      target_port = "http-grafana"
    }

    selector = {
      app = "grafana"
    }

    type             = "LoadBalancer"
    session_affinity = "None"
  }
}
resource "kubernetes_service_account" "telegraf_ds" {
  metadata {
    name      = "telegraf-ds"
    namespace = "metrics"

    labels = {
      "app.kubernetes.io/name" = "telegraf-ds"
    }
  }
}

resource "kubernetes_cluster_role" "influx_stats_viewer" {
  metadata {
    name = "influx-stats-viewer"

    labels = {
      "app.kubernetes.io/name" = "telegraf-ds"
    }
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["metrics.k8s.io"]
    resources  = ["pods"]
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["nodes/proxy", "nodes/stats"]
  }
}

resource "kubernetes_cluster_role_binding" "influx_telegraf_viewer" {
  metadata {
    name = "influx-telegraf-viewer"

    labels = {
      "app.kubernetes.io/name" = "telegraf-ds"
    }
  }

  subject {
    kind      = "ServiceAccount"
    name      = "telegraf-ds"
    namespace = "metrics"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "influx-stats-viewer"
  }
}

resource "kubernetes_config_map" "telegraf" {
  metadata {
    name      = "telegraf"
    namespace = "metrics"

    labels = {
      k8s-app = "telegraf"
    }
  }

  data = {
    "telegraf.conf" = "[global_tags]\n  env = \"$ENV\"\n[agent]\n  hostname = \"$HOSTNAME\"\n[[outputs.influxdb]]\n  urls = [\"$MONITOR_HOST\"] # required\n  database = \"$MONITOR_DATABASE\" # required\n\n  timeout = \"5s\"\n  username = \"$MONITOR_USERNAME\"\n  password = \"$MONITOR_PASSWORD\"\n  \n[[inputs.cpu]]\n  percpu = true\n  totalcpu = true\n  collect_cpu_time = false\n  report_active = false\n[[inputs.disk]]\n  ignore_fs = [\"tmpfs\", \"devtmpfs\", \"devfs\"]\n[[inputs.diskio]]\n[[inputs.kernel]]\n[[inputs.mem]]\n[[inputs.processes]]\n[[inputs.swap]]\n[[inputs.system]]\n[[inputs.net]]\n[[inputs.kubernetes]]\n  insecure_skip_verify = true\n  url = \"https://$HOST_IP:10250\"\n  bearer_token = \"/run/secrets/kubernetes.io/serviceaccount/token\"\n\n"
  }
}

resource "kubernetes_daemonset" "telegraf" {
  metadata {
    name      = "telegraf"
    namespace = "metrics"

    labels = {
      k8s-app = "telegraf"
    }
  }

  spec {
    selector {
      match_labels = {
        name = "telegraf"
      }
    }

    template {
      metadata {
        labels = {
          name = "telegraf"
        }
      }

      spec {
        volume {
          name = "sys"

          host_path {
            path = "/sys"
          }
        }

        volume {
          name = "proc"

          host_path {
            path = "/proc"
          }
        }

        volume {
          name = "config"

          config_map {
            name = "telegraf"
          }
        }

        container {
          name  = "telegraf"
          image = "docker.io/telegraf:1.24.3"

          env {
            name = "HOSTNAME"

            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name  = "HOST_PROC"
            value = "/rootfs/proc"
          }

          env {
            name  = "HOST_SYS"
            value = "/rootfs/sys"
          }

          env {
            name  = "ENV"
            value = "prod"
          }

          env {
            name  = "MONITOR_USERNAME"
            value = "lrdata"
          }

          env {
            name  = "MONITOR_PASSWORD"
            value = "lrdata-pw"
          }

          env {
            name  = "MONITOR_HOST"
            value = "http://influxdb.metrics:8086"
          }

          env {
            name  = "MONITOR_DATABASE"
            value = "metrics"
          }

          env {
            name = "HOST_IP"

            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          resources {
            limits = {
              memory = "500Mi"
            }

            requests = {
              cpu = "500m"

              memory = "500Mi"
            }
          }

          volume_mount {
            name       = "sys"
            read_only  = true
            mount_path = "/rootfs/sys"
          }

          volume_mount {
            name       = "proc"
            read_only  = true
            mount_path = "/rootfs/proc"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/telegraf"
          }
        }

        termination_grace_period_seconds = 30
        service_account_name             = "telegraf-ds"
      }
    }
  }
}

