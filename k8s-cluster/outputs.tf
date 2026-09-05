output "k3s_server_instance_id" {
  value = aws_instance.k3s_server.id
}

output "queue_urls" {
  value = local.queue_urls
}
