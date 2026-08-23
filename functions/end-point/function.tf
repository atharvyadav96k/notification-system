terraform {
  backend "s3" {}
}

variable "function-name" {
  type = string
}

variable "region" {
  type = string
}

variable "state_bucket" {
  type = string
}

variable "lambda_role_arn" {
  type = string
}

variable "SQL" {
    type = string
}

provider "aws" {
  region = var.region
}

data "aws_sqs_queue" "notification_queue" {
  name =  var.SQL
}

resource "aws_s3_object" "function_zip" {
  bucket = var.state_bucket
  key    = "artifacts/${var.function-name}/function.zip"
  source = "${path.module}/function.zip"
  etag   = filemd5("${path.module}/function.zip")
}

resource "aws_lambda_function" "notification_publisher" {
  function_name    = var.function-name
  role             = var.lambda_role_arn
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  architectures    = ["x86_64"]
  s3_bucket        = aws_s3_object.function_zip.bucket
  s3_key           = aws_s3_object.function_zip.key
  source_code_hash = filebase64sha256("${path.module}/function.zip")
  environment {
    variables = {
      SQS_QUEUE_URL = data.aws_sqs_queue.notification_queue.url
    }
  }
  depends_on = [aws_s3_object.function_zip]
}
