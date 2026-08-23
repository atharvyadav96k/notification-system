resource "kubernetes_secret_v1" "rabbitmq_conn" {
  metadata {
    name      = "rabbitmq-conn"
    namespace = kubernetes_namespace_v1.notification_system.metadata[0].name
  }

  data = {
    RABBITMQ_URL = var.rabbitmq_url
  }

  type = "Opaque"
}

resource "kubernetes_deployment_v1" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace_v1.notification_system.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "rabbitmq"
      }
    }

    template {
      metadata {
        labels = {
          app = "rabbitmq"
        }
      }

      spec {
        container {
          name  = "rabbitmq"
          image = "rabbitmq:3-management"

          port {
            container_port = 5672
          }
          port {
            container_port = 15672
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace_v1.notification_system.metadata[0].name
  }

  spec {
    selector = {
      app = "rabbitmq"
    }

    port {
      name        = "amqp"
      port        = 5672
      target_port = 5672
    }
    port {
      name        = "management"
      port        = 15672
      target_port = 15672
    }
  }
}
