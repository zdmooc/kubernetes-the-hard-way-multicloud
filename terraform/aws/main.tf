# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Provider: Amazon Web Services (AWS)
# Fichier: main.tf
# Auteur: Zidane Djamal
# ==============================================================================

provider "aws" {
  region = var.aws_region
}

# ------------------------------------------------------------------------------
# 1. Réseau (VPC, Subnet, IGW, Route Table)
# ------------------------------------------------------------------------------
resource "aws_vpc" "k8s_vpc" {
  cidr_block           = "10.240.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "k8s-thw-vpc"
  }
}

resource "aws_subnet" "k8s_subnet" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = "10.240.0.0/24"
  availability_zone       = var.aws_az
  map_public_ip_on_launch = true

  tags = {
    Name = "k8s-thw-subnet"
  }
}

resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "k8s-thw-igw"
  }
}

resource "aws_route_table" "k8s_rt" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s_igw.id
  }

  tags = {
    Name = "k8s-thw-rt"
  }
}

resource "aws_route_table_association" "k8s_rta" {
  subnet_id      = aws_subnet.k8s_subnet.id
  route_table_id = aws_route_table.k8s_rt.id
}

# ------------------------------------------------------------------------------
# 2. Security Groups
# ------------------------------------------------------------------------------
resource "aws_security_group" "k8s_sg" {
  name        = "k8s-thw-sg"
  description = "Kubernetes The Hard Way Security Group"
  vpc_id      = aws_vpc.k8s_vpc.id

  # Internal Traffic (VPC & Pod CIDR)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.240.0.0/24", "10.200.0.0/16"]
  }

  # SSH External
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API External
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ICMP External (Ping)
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound Traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-thw-sg"
  }
}

# ------------------------------------------------------------------------------
# 3. Key Pair
# ------------------------------------------------------------------------------
resource "aws_key_pair" "k8s_key" {
  key_name   = "k8s-thw-key"
  public_key = file(var.ssh_public_key_path)
}

# ------------------------------------------------------------------------------
# 4. Data Source: Ubuntu 22.04 AMI
# ------------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ------------------------------------------------------------------------------
# 5. Instances EC2 (VMs)
# ------------------------------------------------------------------------------
# Note : source_dest_check = false est requis pour le routage des pods sur les workers

resource "aws_instance" "jumpbox" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.k8s_subnet.id
  private_ip    = "10.240.0.10"
  key_name      = aws_key_pair.k8s_key.key_name

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "jumpbox"
  }
}

resource "aws_instance" "server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type_server
  subnet_id     = aws_subnet.k8s_subnet.id
  private_ip    = "10.240.0.11"
  key_name      = aws_key_pair.k8s_key.key_name

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  tags = {
    Name = "server"
  }
}

resource "aws_instance" "node_0" {
  ami               = data.aws_ami.ubuntu.id
  instance_type     = var.instance_type_worker
  subnet_id         = aws_subnet.k8s_subnet.id
  private_ip        = "10.240.0.20"
  key_name          = aws_key_pair.k8s_key.key_name
  source_dest_check = false

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  tags = {
    Name = "node-0"
  }
}

resource "aws_instance" "node_1" {
  ami               = data.aws_ami.ubuntu.id
  instance_type     = var.instance_type_worker
  subnet_id         = aws_subnet.k8s_subnet.id
  private_ip        = "10.240.0.21"
  key_name          = aws_key_pair.k8s_key.key_name
  source_dest_check = false

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  tags = {
    Name = "node-1"
  }
}

# ------------------------------------------------------------------------------
# 6. Routes statiques pour le trafic des Pods (Pod CIDR)
# ------------------------------------------------------------------------------
resource "aws_route" "route_node_0" {
  route_table_id         = aws_route_table.k8s_rt.id
  destination_cidr_block = "10.200.0.0/24"
  network_interface_id   = aws_instance.node_0.primary_network_interface_id
}

resource "aws_route" "route_node_1" {
  route_table_id         = aws_route_table.k8s_rt.id
  destination_cidr_block = "10.200.1.0/24"
  network_interface_id   = aws_instance.node_1.primary_network_interface_id
}

# ------------------------------------------------------------------------------
# 7. Génération de l'Inventory (Contrat d'interface)
# ------------------------------------------------------------------------------
resource "local_file" "inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    provider           = "aws"
    region             = var.aws_region
    zone               = var.aws_az
    jumpbox_public_ip  = aws_instance.jumpbox.public_ip
    server_public_ip   = aws_instance.server.public_ip
    node_0_public_ip   = aws_instance.node_0.public_ip
    node_1_public_ip   = aws_instance.node_1.public_ip
    jumpbox_private_ip = aws_instance.jumpbox.private_ip
    server_private_ip  = aws_instance.server.private_ip
    node_0_private_ip  = aws_instance.node_0.private_ip
    node_1_private_ip  = aws_instance.node_1.private_ip
    pod_cidr           = var.pod_cidr
    service_cidr       = var.service_cidr
    cluster_dns        = var.cluster_dns
    ssh_user           = var.ssh_user
    ssh_key_path       = replace(var.ssh_public_key_path, ".pub", "")
  })
  filename = "${path.module}/../../inventories/aws/inventory.env"
}
