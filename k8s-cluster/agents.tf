data "aws_iam_policy_document" "k3s_agent_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "k3s_agent" {
  name               = "${var.cluster_name}-k3s-agent-role"
  assume_role_policy = data.aws_iam_policy_document.k3s_agent_assume_role.json
}

data "aws_iam_policy_document" "k3s_agent" {
  statement {
    sid = "ConsumeAllPriorityQueues"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [
      local.queue_arns.high,
      local.queue_arns.medium,
      local.queue_arns.low,
    ]
  }

  statement {
    sid       = "K3sTokenAndAddressRead"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:${var.region}:*:parameter${local.ssm_token_param}", "arn:aws:ssm:${var.region}:*:parameter${local.ssm_server_addr_param}"]
  }
}

resource "aws_iam_policy" "k3s_agent" {
  name   = "${var.cluster_name}-k3s-agent-policy"
  policy = data.aws_iam_policy_document.k3s_agent.json
}

resource "aws_iam_role_policy_attachment" "k3s_agent" {
  role       = aws_iam_role.k3s_agent.name
  policy_arn = aws_iam_policy.k3s_agent.arn
}

resource "aws_iam_instance_profile" "k3s_agent" {
  name = "${var.cluster_name}-k3s-agent-profile"
  role = aws_iam_role.k3s_agent.name
}

resource "aws_security_group" "k3s_agent" {
  name   = "${var.cluster_name}-k3s-agent-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "flannel VXLAN from server"
    from_port       = 8472
    to_port         = 8472
    protocol        = "udp"
    security_groups = [aws_security_group.k3s_server.id]
  }

  ingress {
    description = "flannel VXLAN between agents"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    self        = true
  }

  ingress {
    description     = "kubelet from server"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.k3s_server.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "server_from_agents_vxlan" {
  type                     = "ingress"
  from_port                = 8472
  to_port                  = 8472
  protocol                 = "udp"
  security_group_id        = aws_security_group.k3s_server.id
  source_security_group_id = aws_security_group.k3s_agent.id
}

resource "aws_launch_template" "agent" {
  for_each = local.agent_max_size

  name_prefix   = "${var.cluster_name}-k3s-agent-${each.key}-"
  image_id      = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type = var.agent_instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.k3s_agent.name
  }

  vpc_security_group_ids = [aws_security_group.k3s_agent.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euo pipefail

    dnf install -y awscli

    for i in $(seq 1 30); do
      SERVER_IP=$(aws ssm get-parameter --region "${var.region}" --name "${local.ssm_server_addr_param}" --with-decryption --query Parameter.Value --output text 2>/dev/null || true)
      [ -n "$SERVER_IP" ] && break
      sleep 5
    done
    TOKEN=$(aws ssm get-parameter --region "${var.region}" --name "${local.ssm_token_param}" --with-decryption --query Parameter.Value --output text)

    curl -sfL https://get.k3s.io | \
      K3S_URL="https://$${SERVER_IP}:6443" K3S_TOKEN="$TOKEN" \
      sh -s - agent --node-label "priority=${each.key}"
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.cluster_name}-k3s-agent-${each.key}"
    }
  }
}

resource "aws_autoscaling_group" "agent" {
  for_each = local.agent_max_size

  name                = "${var.cluster_name}-k3s-agent-${each.key}"
  min_size            = 0
  max_size            = each.value
  desired_capacity    = 0
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.agent[each.key].id
    version = "$Latest"
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-k3s-agent-${each.key}"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/priority"
    value               = each.key
    propagate_at_launch = false
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/resources/cpu"
    value               = "2"
    propagate_at_launch = false
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/resources/memory"
    value               = "1Gi"
    propagate_at_launch = false
  }
}
