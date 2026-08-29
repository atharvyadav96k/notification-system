terraform {
  backend "s3" {}
}

variable "region" {
  type = string
}

resource "aws_instance" "ubentu"{
    ami = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
    instance_type = "t3.micro"
    region = var.region

    user_data = <<-EOF
    #!/bin/bash
    echo "install go"
    sudo dnf install golang-1.25.5
    go version
    
    echo "instal git"
    sudo dnf install git

    echo "Pull the code"
    git clone https://github.com/atharvyadav96k/notification-system-1m.git

    cd ./notification-system-1m/worker/consumer
    echo "Install Dependencies"
    go mod tidy
    echo "run the code"
    go run worker.go
    EOF
    tags = {
        Name = "Worker"
    }
}
