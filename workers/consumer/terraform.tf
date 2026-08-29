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
    tags = {
        Name = "Worker"
    }
}