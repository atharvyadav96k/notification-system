terraform {
  backend "s3" {}
}

variable "sqs_queue" {
    type = string
}

variable "region" {
  type = string
}

provider "aws" {
  region = var.region
}

variable "function_name" {
  type    = string
  default = "sqs-trigger"
}


data "aws_lambda_function" "sqs_trigger" {
  function_name = var.function_name
}

resource "aws_lambda_permission" "allow_cloudwatch_alarm" {
  statement_id  = "AllowCloudWatchAlarmInvoke"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.sqs_trigger.function_name
  principal     = "lambda.alarms.cloudwatch.amazonaws.com"
  source_arn    = aws_cloudwatch_metric_alarm.sqs_has_messages.arn
}

resource "aws_cloudwatch_metric_alarm" "sqs_has_messages" {
  alarm_name          = "notification-queue-has-messages"
  alarm_description   = "Start EC2 worker when SQS has messages"

  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"

  dimensions = {
    QueueName = var.sqs_queue
  }

  statistic           = "Maximum"
  period              = 30

  comparison_operator = "GreaterThanThreshold"
  threshold           = 0

  evaluation_periods  = 1
  datapoints_to_alarm = 1

  treat_missing_data  = "notBreaching"

  alarm_actions = [
    data.aws_lambda_function.sqs_trigger.arn
  ]
}