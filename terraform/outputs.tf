output "worker_image" {
  description = "Image pushed to the local registry and deployed to the worker Deployment"
  value       = docker_image.worker.name
}
