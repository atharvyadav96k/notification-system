locals {
  ssm_token_param       = "/${var.cluster_name}/k3s/agent-token"
  ssm_server_addr_param = "/${var.cluster_name}/k3s/server-addr"
}

resource "aws_security_group" "k3s_server" {
  name   = "${var.cluster_name}-k3s-server-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "k3s API server (in-VPC only)"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  ingress {
    description = "flannel VXLAN"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    self        = true
  }

  ingress {
    description = "kubelet"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_iam_policy_document" "k3s_server_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "k3s_server" {
  name               = "${var.cluster_name}-k3s-server-role"
  assume_role_policy = data.aws_iam_policy_document.k3s_server_assume_role.json
}

data "aws_iam_policy_document" "k3s_server" {
  statement {
    sid     = "ReadQueueDepthForKeda"
    actions = ["sqs:GetQueueAttributes"]
    resources = [
      local.queue_arns.high,
      local.queue_arns.medium,
      local.queue_arns.low,
    ]
  }

  statement {
    sid = "ClusterAutoscalerReadOnly"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ClusterAutoscalerScale"
    actions   = ["autoscaling:SetDesiredCapacity", "autoscaling:TerminateInstanceInAutoScalingGroup"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}"
      values   = ["owned"]
    }
  }

  statement {
    sid       = "K3sTokenAndAddressReadWrite"
    actions   = ["ssm:PutParameter", "ssm:GetParameter"]
    resources = ["arn:aws:ssm:${var.region}:*:parameter${local.ssm_token_param}", "arn:aws:ssm:${var.region}:*:parameter${local.ssm_server_addr_param}"]
  }
}

resource "aws_iam_policy" "k3s_server" {
  name   = "${var.cluster_name}-k3s-server-policy"
  policy = data.aws_iam_policy_document.k3s_server.json
}

resource "aws_iam_role_policy_attachment" "k3s_server" {
  role       = aws_iam_role.k3s_server.name
  policy_arn = aws_iam_policy.k3s_server.arn
}

resource "aws_iam_role_policy_attachment" "k3s_server_ssm_core" {
  role       = aws_iam_role.k3s_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "k3s_server" {
  name = "${var.cluster_name}-k3s-server-profile"
  role = aws_iam_role.k3s_server.name
}

resource "aws_instance" "k3s_server" {
  ami           = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type = var.server_instance_type

  vpc_security_group_ids      = [aws_security_group.k3s_server.id]
  iam_instance_profile        = aws_iam_instance_profile.k3s_server.name
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    dnf install -y awscli

    echo "install k3s server"
    curl -sfL https://get.k3s.io | sh -s - server --write-kubeconfig-mode 644

    SERVER_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
    aws ssm put-parameter --region "${var.region}" --name "${local.ssm_server_addr_param}" \
      --type SecureString --overwrite --value "$SERVER_IP"

    for i in $(seq 1 30); do
      [ -f /var/lib/rancher/k3s/server/node-token ] && break
      sleep 2
    done
    aws ssm put-parameter --region "${var.region}" --name "${local.ssm_token_param}" \
      --type SecureString --overwrite --value "$(cat /var/lib/rancher/k3s/server/node-token)"

    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

    echo "install helm"
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    helm repo add kedacore https://kedacore.github.io/charts
    helm repo add autoscaler https://kubernetes.github.io/autoscaler
    helm repo update

    helm upgrade --install keda kedacore/keda \
      --namespace keda-system --create-namespace

    helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
      --namespace kube-system \
      --set autoDiscovery.clusterName=${var.cluster_name} \
      --set awsRegion=${var.region} \
      --set cloudProvider=aws \
      --set extraArgs.balance-similar-node-groups=false \
      --set extraArgs.scale-down-enabled=true
  EOF

  tags = {
    Name = "${var.cluster_name}-k3s-server"
  }
}
