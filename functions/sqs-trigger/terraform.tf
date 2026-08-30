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

provider "aws" {
  region = var.region
}

resource "aws_s3_object" "function_zip" {
  bucket = var.state_bucket
  key    = "artifacts/${var.function-name}/function.zip"
  source = "${path.module}/function.zip"
  etag   = filemd5("${path.module}/function.zip")
}

locals {
  lambda_role_name = element(split("/", var.lambda_role_arn), length(split("/", var.lambda_role_arn)) - 1)
}

resource "aws_iam_policy" "lambda_ec2_start_policy" {
  name        = "${var.function-name}-ec2-start-policy"
  description = "Allows Lambda to start the worker EC2 instance"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances", "ec2:StartInstances"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ec2_start_policy" {
  role       = local.lambda_role_name
  policy_arn = aws_iam_policy.lambda_ec2_start_policy.arn
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
    aws_s3_object.function_zip,
    aws_iam_role_policy_attachment.attach_ec2_start_policy
  ]
}