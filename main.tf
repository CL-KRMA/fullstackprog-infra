provider "aws" {
  region = "us-east-1"
}

# VPC avec plage 192.168.2.0/24
resource "aws_vpc" "main" {
  cidr_block = "192.168.2.0/24"
}

# Subnet unique couvrant tout le réseau (forcé en us-east-1a)
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "192.168.2.0/24"
  availability_zone = "us-east-1a"
}

# Internet Gateway
resource "aws_internet_gateway" "main_gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Main-Gateway"
  }
}

# Route Table publique
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_gw.id
  }

  tags = {
    Name = "Public-RT"
  }
}

# Associer la Route Table au subnet
resource "aws_route_table_association" "main_assoc" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group adapté à K3s + HTTP/HTTPS
resource "aws_security_group" "k3s_sg" {
  name        = "k3s_cluster_sg"
  description = "Allow SSH, ICMP, K3s, HTTP and HTTPS"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ICMP
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # K3s API
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["192.168.2.0/24"]
  }

  # K3s VXLAN
  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = ["192.168.2.0/24"]
  }

  # Kubelet
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["192.168.2.0/24"]
  }

  # NodePorts
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Sortie libre
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Key Pair
resource "aws_key_pair" "my_key" {
  key_name   = "ma-cle-ssh"
  public_key = file("${path.module}/keys/ma-cle-ssh.pub")
}

# VPS1 - Master
resource "aws_instance" "ubuntu_vps1" {
  ami           = "ami-08c40ec9ead489470"
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.main_subnet.id
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  private_ip    = "192.168.2.10"
  key_name      = aws_key_pair.my_key.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "Ubuntu-VPS1-Master"
  }
}

resource "aws_eip" "vps1_ip" {
  instance = aws_instance.ubuntu_vps1.id
}

# VPS2 - Worker
resource "aws_instance" "ubuntu_vps2" {
  ami           = "ami-08c40ec9ead489470"
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.main_subnet.id
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  private_ip    = "192.168.2.11"
  key_name      = aws_key_pair.my_key.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "Ubuntu-VPS2-Worker"
  }
}

resource "aws_eip" "vps2_ip" {
  instance = aws_instance.ubuntu_vps2.id
}

# VPS3 - Worker
resource "aws_instance" "ubuntu_vps3" {
  ami           = "ami-08c40ec9ead489470"
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.main_subnet.id
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  private_ip    = "192.168.2.12"
  key_name      = aws_key_pair.my_key.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "Ubuntu-VPS3-Worker"
  }
}

resource "aws_eip" "vps3_ip" {
  instance = aws_instance.ubuntu_vps3.id
}

# Outputs
output "vps1_private_ip" {
  value = aws_instance.ubuntu_vps1.private_ip
}
output "vps1_public_ip" {
  value = aws_eip.vps1_ip.public_ip
}

output "vps2_private_ip" {
  value = aws_instance.ubuntu_vps2.private_ip
}
output "vps2_public_ip" {
  value = aws_eip.vps2_ip.public_ip
}

output "vps3_private_ip" {
  value = aws_instance.ubuntu_vps3.private_ip
}
output "vps3_public_ip" {
  value = aws_eip.vps3_ip.public_ip
}
