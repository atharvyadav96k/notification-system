provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {}
}

variable "region" {
  type = string
}

variable "SQS_NAME" {
  type = string
}

variable "docker_image" {
  type = string
}

data "aws_sqs_queue" "notification_queue" {
  name = var.SQS_NAME
}

data "aws_iam_policy_document" "worker_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "worker" {
  name               = "notification-worker-role"
  assume_role_policy = data.aws_iam_policy_document.worker_assume_role.json
}

data "aws_iam_policy_document" "worker_sqs" {
  statement {
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [data.aws_sqs_queue.notification_queue.arn]
  }
}

resource "aws_iam_role_policy" "worker_sqs" {
  name   = "notification-worker-sqs-policy"
  role   = aws_iam_role.worker.id
  policy = data.aws_iam_policy_document.worker_sqs.json
}

resource "aws_iam_instance_profile" "worker" {
  name = "notification-worker-profile"
  role = aws_iam_role.worker.name
}

resource "aws_security_group" "worker-security" {
  name = "notification-worker-sg"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "worker"{
    ami = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
    instance_type = "t3.micro"

    vpc_security_group_ids     = [aws_security_group.worker-security.id]
    iam_instance_profile       = aws_iam_instance_profile.worker.name
    user_data_replace_on_change = true

    metadata_options {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
    }


    user_data = <<-EOF
    #!/bin/bash
    echo "install docker"
    sudo dnf install -y docker
    sudo systemctl enable --now docker

    mkdir -p /home/ec2-user

    echo "install worker run script"
    cat <<-'SCRIPT' | sudo tee /usr/local/bin/run-worker.sh
    ${file("${path.module}/run-worker.sh")}
    SCRIPT
    sudo chmod +x /usr/local/bin/run-worker.sh

    echo "create worker service"
    cat <<-'UNIT' | sudo tee /etc/systemd/system/worker.service
    [Unit]
    Description=Notification SQS worker
    After=network.target docker.service
    Requires=docker.service

    [Service]
    Type=simple
    Environment=DOCKER_IMAGE=${var.docker_image}
    Environment=AWS_REGION=${var.region}
    Environment=SQS_QUEUE_URL=${data.aws_sqs_queue.notification_queue.url}
    ExecStart=/usr/local/bin/run-worker.sh
    ExecStop=/usr/bin/docker stop worker
    Restart=always
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
    UNIT

    echo "start the worker"
    sudo systemctl daemon-reload
    sudo systemctl enable --now worker
    EOF
    tags = {
        Name = "Worker"
    }
}

