terraform {
  backend "s3" {}
}

variable "region" {
  type = string
}

variable "state_bucket" {
  type        = string
  description = "S3 bucket holding this repo's Terraform state (used to read the sqs/* stacks' remote state)."
}

variable "cluster_name" {
  type    = string
  default = "notification-system"
}

variable "server_instance_type" {
  type    = string
  default = "t3.small"
}

variable "agent_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "high_max_size" {
  type    = number
  default = 5
}

variable "medium_max_size" {
  type    = number
  default = 2
}

variable "low_max_size" {
  type    = number
  default = 1
}

provider "aws" {
  region = var.region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "terraform_remote_state" "sqs_high" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "state/notification-sqs-high/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "sqs_medium" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "state/notification-sqs-medium/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "sqs_low" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "state/notification-sqs-low/terraform.tfstate"
    region = var.region
  }
}

locals {
  queue_urls = {
    high   = data.terraform_remote_state.sqs_high.outputs.sqs_queue_url
    medium = data.terraform_remote_state.sqs_medium.outputs.sqs_queue_url
    low    = data.terraform_remote_state.sqs_low.outputs.sqs_queue_url
  }
  queue_arns = {
    high   = data.terraform_remote_state.sqs_high.outputs.sqs_queue_arn
    medium = data.terraform_remote_state.sqs_medium.outputs.sqs_queue_arn
    low    = data.terraform_remote_state.sqs_low.outputs.sqs_queue_arn
  }
  agent_max_size = {
    high   = var.high_max_size
    medium = var.medium_max_size
    low    = var.low_max_size
  }
}
