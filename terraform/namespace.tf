resource "kubernetes_namespace_v1" "notification_system" {
  metadata {
    name = var.namespace
  }
}
