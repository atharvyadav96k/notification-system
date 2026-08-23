resource "kubernetes_manifest" "rabbitmq_trigger_auth" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "TriggerAuthentication"
    metadata = {
      name      = "rabbitmq-trigger-auth"
      namespace = kubernetes_namespace_v1.notification_system.metadata[0].name
    }
    spec = {
      secretTargetRef = [
        {
          parameter = "host"
          name      = kubernetes_secret_v1.rabbitmq_conn.metadata[0].name
          key       = "RABBITMQ_URL"
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "worker_scaled_object" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "ScaledObject"
    metadata = {
      name      = "notification-worker-scaler"
      namespace = kubernetes_namespace_v1.notification_system.metadata[0].name
    }
    spec = {
      scaleTargetRef = {
        name = kubernetes_deployment_v1.worker.metadata[0].name
      }

      minReplicaCount = 1
      maxReplicaCount = 20
      cooldownPeriod  = 30
      pollingInterval = 5

      triggers = [
        {
          type = "rabbitmq"
          metadata = {
            queueName = "notification"
            mode      = "QueueLength"
            value     = "50"
          }
          authenticationRef = {
            name = "rabbitmq-trigger-auth"
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.rabbitmq_trigger_auth]
}
