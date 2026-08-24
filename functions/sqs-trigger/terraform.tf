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

variable "SQS_NAME" {
  type = string
}

provider "aws" {
  region = var.region
}

data "aws_sqs_queue" "notification_queue" {
  name = var.SQS_NAME
}

locals {
    lambda_role_name = element(split("/", var.lambda_role_arn), length(split("/", var.lambda_role_arn)) - 1)
}

resource "aws_iam_policy" "lambda_sqs_receive_policy" {
  name        = "${var.function-name}-sqs-receive-policy"
  description = "Allows Lambda to receive messages from SQS queue ${var.SQS_NAME}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = data.aws_sqs_queue.notification_queue.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_sqs_receive_policy" {
  role       = local.lambda_role_name
  policy_arn = aws_iam_policy.lambda_sqs_receive_policy.arn
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = data.aws_sqs_queue.notification_queue.arn
  function_name    = aws_lambda_function.notification_publisher.arn
  batch_size       = 10

  depends_on = [
    aws_iam_role_policy_attachment.attach_sqs_receive_policy
  ]
}

resource "aws_s3_object" "function_zip" {
  bucket = var.state_bucket
  key    = "artifacts/${var.function-name}/function.zip"
  source = "${path.module}/function.zip"
  etag   = filemd5("${path.module}/function.zip")
}

resource "aws_lambda_permission" "function_url_public_access" {
  statement_id           = "AllowPublicFunctionUrlInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.notification_publisher.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_function_url" "publisher_url" {
  function_name      = aws_lambda_function.notification_publisher.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["POST", "GET"]
    allow_headers     = ["*"]
  }
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
  
  depends_on = [
    aws_s3_object.function_zip
  ]
}