variable "SQS_NAME" {
    type = string
}

resource "aws_sqs_queue" "notification_dlq" {
  name                      = var.SQS_NAME
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "notification_queue" {
  name                       = var.SQS_NAME
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 10
  visibility_timeout_seconds = 30

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notification_dlq.arn
    maxReceiveCount     = 5
  })
}

output "sqs_queue_url" {
  value       = aws_sqs_queue.notification_queue.id
}

output "sqs_queue_arn" {
  value       = aws_sqs_queue.notification_queue.arn
}