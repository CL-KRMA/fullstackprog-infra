# ============================================================
# Variables
# ============================================================
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "allowed_ssh_cidr" {
  description = "CIDR autorisé pour SSH (remplace par ton IP : 'x.x.x.x/32')"
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_type" {
  description = "Type d'instance"
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "AMI Ubuntu 22.04 LTS (us-east-1)"
  type        = string
  default     = "ami-08c40ec9ead489470"
}

variable "volume_size" {
  description = "Taille du disque en GB"
  type        = number
  default     = 20
}

variable "key_name" {
  description = "Nom de la clé SSH"
  type        = string
  default     = "ma-cle-ssh"
}

variable "project_name" {
  description = "Nom du projet (utilisé pour les tags)"
  type        = string
  default     = "k3s-cluster"
}

# ============================================================
# Provider
# ============================================================
provider "aws" {
  region = var.region
}

# ============================================================
# Réseau
# ============================================================
resource "aws_vpc" "main" {
  cidr_block           = "192.168.2.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "192.168.2.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false

  tags = {
    Name    = "${var.project_name}-public-subnet"
    Project = var.project_name
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ============================================================
# Security Group
# ============================================================
resource "aws_security_group" "k3s" {
  name        = "${var.project_name}-sg"
  description = "Allow SSH, ICMP, K3s, HTTP, HTTPS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "K3s API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  ingress {
    description = "K3s VXLAN"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  ingress {
    description = "Kubelet"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  ingress {
    description = "NodePorts"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
  }
}

# ============================================================
# Clé SSH
# ============================================================
resource "aws_key_pair" "main" {
  key_name   = var.key_name
  public_key = file("${path.module}/keys/${var.key_name}.pub")

  tags = {
    Project = var.project_name
  }
}

# ============================================================
# Locals
# ============================================================
locals {
  nodes = {
    master   = { private_ip = "192.168.2.10", role = "master" }
    worker-1 = { private_ip = "192.168.2.11", role = "worker" }
    worker-2 = { private_ip = "192.168.2.12", role = "worker" }
  }
}

# ============================================================
# Instances EC2
# ============================================================
resource "aws_instance" "nodes" {
  for_each = local.nodes

  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.k3s.id]
  private_ip                  = each.value.private_ip
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = false

  root_block_device {
    volume_size           = var.volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name    = "${var.project_name}-${each.key}"
    Role    = each.value.role
    Project = var.project_name
  }
}

# ============================================================
# Elastic IPs
# ============================================================
resource "aws_eip" "nodes" {
  for_each = local.nodes
  instance = aws_instance.nodes[each.key].id
  domain   = "vpc"

  tags = {
    Name    = "${var.project_name}-eip-${each.key}"
    Project = var.project_name
  }
}

# ============================================================
# Outputs
# ============================================================
output "nodes" {
  description = "IPs publiques et privées des nœuds"
  value = {
    for name in keys(local.nodes) : name => {
      private_ip = aws_instance.nodes[name].private_ip
      public_ip  = aws_eip.nodes[name].public_ip
      role       = local.nodes[name].role
    }
  }
}

output "cluster_summary" {
  description = "Résumé du cluster"
  value = {
    master   = aws_eip.nodes["master"].public_ip
    worker_1 = aws_eip.nodes["worker-1"].public_ip
    worker_2 = aws_eip.nodes["worker-2"].public_ip
    region   = var.region
  }
}

output "ssh_commands" {
  description = "Commandes SSH pour se connecter aux nœuds"
  value = {
    for name in keys(local.nodes) :
    name => "ssh -i keys/${var.key_name} ubuntu@${aws_eip.nodes[name].public_ip}"
  }
}
