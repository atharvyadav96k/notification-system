provider "aws" {}

terraform {
  backend "s3" {}
}

variable "region" {
  type = string
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

    vpc_security_group_ids = [aws_security_group.worker-security.id]
    user_data = <<-EOF
    #!/bin/bash
    echo "install go"
    sudo dnf install -y golang-1.25.5
    go version

    echo "instal git"
    sudo dnf install -y git

    echo "Pull the code"
    git clone https://github.com/atharvyadav96k/notification-system-1m.git

    cd ./notification-system-1m/worker/consumer
    echo "Install Dependencies"
    go mod tidy
    echo "run the code"
    nohup go run worker.go > /var/log/worker.log 2>&1 &
    EOF
    tags = {
        Name = "Worker"
    }
}