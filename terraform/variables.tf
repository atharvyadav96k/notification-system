variable "kubeconfig_path" {
  description = "Path to the kubeconfig file for the local kind/minikube cluster"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubeconfig context to use (empty string = current-context)"
  type        = string
  default     = ""
}

variable "docker_host" {
  description = "Docker daemon socket. Defaults to Docker Desktop on Windows; override for other setups."
  type        = string
  default     = "npipe:////./pipe/docker_engine"
}

variable "registry" {
  description = "Local registry host:port the worker image is pushed to"
  type        = string
  default     = "localhost:5000"
}

variable "namespace" {
  description = "Kubernetes namespace for the notification system"
  type        = string
  default     = "notification-system"
}

variable "rabbitmq_url" {
  description = "AMQP connection URL the worker uses to reach RabbitMQ (e.g. amqp://guest:guest@rabbitmq:5672/)"
  type        = string
  sensitive   = true
}

variable "worker_replicas" {
  description = "Baseline replica count for the worker deployment (KEDA scales it above this under load)"
  type        = number
  default     = 1
}
