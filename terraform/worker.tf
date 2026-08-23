resource "kubernetes_deployment_v1" "worker" {
  metadata {
    name      = "notification-worker"
    namespace = kubernetes_namespace_v1.notification_system.metadata[0].name
  }

  spec {
    replicas = var.worker_replicas

    selector {
      match_labels = {
        app = "notification-worker"
      }
    }

    template {
      metadata {
        labels = {
          app = "notification-worker"
        }
      }

      spec {
        container {
          name              = "notification-worker"
          image             = docker_image.worker.name
          image_pull_policy = "Always"

          env {
            name = "RABBITMQ_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.rabbitmq_conn.metadata[0].name
                key  = "RABBITMQ_URL"
              }
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }
    }
  }

  # KEDA drives replica count at runtime; don't fight it on apply.
  lifecycle {
    ignore_changes = [spec[0].replicas]
  }

  depends_on = [null_resource.push_worker]
}
