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
    echo "user_data ran at $(date)" > /home/ec2-user/userdata_ran.txt

    echo "install git"
    sudo dnf install -y git
    git --version >> /home/ec2-user/userdata_ran.txt
    EOF
    tags = {
        Name = "Worker"
    }
}