# KEDA isn't a managed Terraform resource upstream, so install its operator
# and CRDs directly. `kubectl apply` is idempotent, and re-running it on
# every apply means a wiped/fresh cluster self-heals on the next apply
# instead of requiring a manual install step first.
resource "null_resource" "keda_install" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "kubectl apply --server-side --force-conflicts -f https://github.com/kedacore/keda/releases/download/v${var.keda_version}/keda-${var.keda_version}-core.yaml"
  }
}

# TriggerAuthentication / ScaledObject are KEDA CRDs. The hashicorp/kubernetes
# `kubernetes_manifest` resource needs the CRD's schema already registered in
# the cluster at *plan* time, which breaks on a fresh cluster where KEDA is
# installed in this same apply. `kubectl_manifest` applies raw YAML generically
# without that requirement, so it works on a brand-new cluster in one apply.
resource "kubectl_manifest" "rabbitmq_trigger_auth" {
  yaml_body = yamlencode({
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
  })

  depends_on = [null_resource.keda_install]
}

resource "kubectl_manifest" "worker_scaled_object" {
  yaml_body = yamlencode({
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
  })

  depends_on = [null_resource.keda_install, kubectl_manifest.rabbitmq_trigger_auth]
}
