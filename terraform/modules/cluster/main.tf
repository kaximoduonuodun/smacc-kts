data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = [
      "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*",
      "ubuntu/images/hvm-ssd-gp3/ubuntu-jammy-22.04-amd64-server-*"
    ]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.server_instance_type
  key_name               = var.key_name
  associate_public_ip_address = true
  iam_instance_profile   = var.iam_instance_profile
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [var.security_group_id]

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    kms_key_id            = var.kms_key_arn
    delete_on_termination = true
  }

  user_data = <<-EOF
#!/bin/bash
set -e
apt-get update -y
curl -sfL https://get.k3s.io | K3S_TOKEN=mytokendemo123 sh -s - server --write-kubeconfig-mode 644 --tls-san $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4) --node-name k3s-server
EOF

  tags = {
    Name        = "${var.project_name}-${var.environment}-k3s-server"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "aws_instance" "agent" {
  count                  = var.agent_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.agent_instance_type
  key_name               = var.key_name
  associate_public_ip_address = true
  iam_instance_profile   = var.iam_instance_profile
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [var.security_group_id]

  root_block_device {
    volume_size           = 15
    volume_type           = "gp3"
    encrypted             = true
    kms_key_id            = var.kms_key_arn
    delete_on_termination = true
  }

  user_data = <<-EOF
#!/bin/bash
set -e
apt-get update -y
until curl -sk https://${aws_instance.server.private_ip}:6443 >/dev/null 2>&1; do
  echo "waiting for server..."
  sleep 10
done
curl -sfL https://get.k3s.io | K3S_URL=https://${aws_instance.server.private_ip}:6443 K3S_TOKEN=mytokendemo123 sh -s - agent --node-name k3s-agent-${count.index + 1}
EOF

  tags = {
    Name        = "${var.project_name}-${var.environment}-k3s-agent-${count.index + 1}"
    environment = var.environment
    managed_by  = "terraform"
  }

  depends_on = [aws_instance.server]
}

