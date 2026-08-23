locals {
  worker_context = abspath("${path.module}/../workers/consumer")
  worker_image_tag  = formatdate("YYYYMMDD-hhmmss", timestamp())
  worker_image_name = "${var.registry}/notification-worker"
  worker_image      = "${local.worker_image_name}:${local.worker_image_tag}"
}

resource "docker_image" "worker" {
  name = local.worker_image

  build {
    context    = local.worker_context
    dockerfile = "Dockerfile"
  }
}
resource "null_resource" "push_worker" {
  triggers = {
    image = docker_image.worker.name
  }

  provisioner "local-exec" {
    command = "docker push ${docker_image.worker.name}"
  }

  depends_on = [docker_image.worker]
}
