# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Provider: IBM Cloud
# Fichier: main.tf
# Auteur: Zidane Djamal
# ==============================================================================

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}

# ------------------------------------------------------------------------------
# 1. Réseau (VPC & Subnet)
# ------------------------------------------------------------------------------
resource "ibm_is_vpc" "k8s_vpc" {
  name = "k8s-thw-vpc"
}

resource "ibm_is_public_gateway" "k8s_pgw" {
  name = "k8s-thw-pgw"
  vpc  = ibm_is_vpc.k8s_vpc.id
  zone = var.zone
}

resource "ibm_is_subnet" "k8s_subnet" {
  name                     = "k8s-thw-subnet"
  vpc                      = ibm_is_vpc.k8s_vpc.id
  zone                     = var.zone
  ipv4_cidr_block          = "10.240.0.0/24"
  public_gateway           = ibm_is_public_gateway.k8s_pgw.id
}

# ------------------------------------------------------------------------------
# 2. Security Group
# ------------------------------------------------------------------------------
resource "ibm_is_security_group" "k8s_sg" {
  name = "k8s-thw-sg"
  vpc  = ibm_is_vpc.k8s_vpc.id
}

resource "ibm_is_security_group_rule" "k8s_sg_rule_ssh" {
  group     = ibm_is_security_group.k8s_sg.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "k8s_sg_rule_api" {
  group     = ibm_is_security_group.k8s_sg.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 6443
    port_max = 6443
  }
}

resource "ibm_is_security_group_rule" "k8s_sg_rule_icmp" {
  group     = ibm_is_security_group.k8s_sg.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  icmp {
    type = 8
  }
}

resource "ibm_is_security_group_rule" "k8s_sg_rule_internal" {
  group     = ibm_is_security_group.k8s_sg.id
  direction = "inbound"
  remote    = "10.240.0.0/24"
}

resource "ibm_is_security_group_rule" "k8s_sg_rule_pods" {
  group     = ibm_is_security_group.k8s_sg.id
  direction = "inbound"
  remote    = "10.200.0.0/16"
}

resource "ibm_is_security_group_rule" "k8s_sg_rule_outbound" {
  group     = ibm_is_security_group.k8s_sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

# ------------------------------------------------------------------------------
# 3. Data Sources (Image & SSH Key)
# ------------------------------------------------------------------------------
data "ibm_is_image" "ubuntu" {
  name = "ibm-ubuntu-22-04-4-minimal-amd64-1"
}

data "ibm_is_ssh_key" "k8s_key" {
  name = var.ssh_key_name
}

# ------------------------------------------------------------------------------
# 4. Instances (Virtual Servers)
# ------------------------------------------------------------------------------
# Note : allow_ip_spoofing = true est requis pour le routage des pods sur les workers

resource "ibm_is_instance" "jumpbox" {
  name    = "jumpbox"
  image   = data.ibm_is_image.ubuntu.id
  profile = "cx2-2x4"
  vpc     = ibm_is_vpc.k8s_vpc.id
  zone    = var.zone
  keys    = [data.ibm_is_ssh_key.k8s_key.id]

  primary_network_interface {
    subnet          = ibm_is_subnet.k8s_subnet.id
    security_groups = [ibm_is_security_group.k8s_sg.id]
    primary_ip {
      address = "10.240.0.10"
    }
  }
}

resource "ibm_is_instance" "server" {
  name    = "server"
  image   = data.ibm_is_image.ubuntu.id
  profile = var.profile
  vpc     = ibm_is_vpc.k8s_vpc.id
  zone    = var.zone
  keys    = [data.ibm_is_ssh_key.k8s_key.id]

  primary_network_interface {
    subnet          = ibm_is_subnet.k8s_subnet.id
    security_groups = [ibm_is_security_group.k8s_sg.id]
    primary_ip {
      address = "10.240.0.11"
    }
  }
}

resource "ibm_is_instance" "node_0" {
  name    = "node-0"
  image   = data.ibm_is_image.ubuntu.id
  profile = var.profile
  vpc     = ibm_is_vpc.k8s_vpc.id
  zone    = var.zone
  keys    = [data.ibm_is_ssh_key.k8s_key.id]

  primary_network_interface {
    subnet            = ibm_is_subnet.k8s_subnet.id
    security_groups   = [ibm_is_security_group.k8s_sg.id]
    allow_ip_spoofing = true
    primary_ip {
      address = "10.240.0.20"
    }
  }
}

resource "ibm_is_instance" "node_1" {
  name    = "node-1"
  image   = data.ibm_is_image.ubuntu.id
  profile = var.profile
  vpc     = ibm_is_vpc.k8s_vpc.id
  zone    = var.zone
  keys    = [data.ibm_is_ssh_key.k8s_key.id]

  primary_network_interface {
    subnet            = ibm_is_subnet.k8s_subnet.id
    security_groups   = [ibm_is_security_group.k8s_sg.id]
    allow_ip_spoofing = true
    primary_ip {
      address = "10.240.0.21"
    }
  }
}

# ------------------------------------------------------------------------------
# 5. Floating IPs (IPs publiques)
# ------------------------------------------------------------------------------
resource "ibm_is_floating_ip" "jumpbox_fip" {
  name   = "k8s-thw-jumpbox-fip"
  target = ibm_is_instance.jumpbox.primary_network_interface[0].id
}

resource "ibm_is_floating_ip" "server_fip" {
  name   = "k8s-thw-server-fip"
  target = ibm_is_instance.server.primary_network_interface[0].id
}

resource "ibm_is_floating_ip" "node_0_fip" {
  name   = "k8s-thw-node-0-fip"
  target = ibm_is_instance.node_0.primary_network_interface[0].id
}

resource "ibm_is_floating_ip" "node_1_fip" {
  name   = "k8s-thw-node-1-fip"
  target = ibm_is_instance.node_1.primary_network_interface[0].id
}

# ------------------------------------------------------------------------------
# 6. Routes statiques (VPC Custom Routes)
# ------------------------------------------------------------------------------
resource "ibm_is_vpc_routing_table_route" "route_node_0" {
  vpc           = ibm_is_vpc.k8s_vpc.id
  routing_table = ibm_is_vpc.k8s_vpc.default_routing_table
  zone          = var.zone
  name          = "route-node-0"
  destination   = "10.200.0.0/24"
  action        = "deliver"
  next_hop      = "10.240.0.20"
}

resource "ibm_is_vpc_routing_table_route" "route_node_1" {
  vpc           = ibm_is_vpc.k8s_vpc.id
  routing_table = ibm_is_vpc.k8s_vpc.default_routing_table
  zone          = var.zone
  name          = "route-node-1"
  destination   = "10.200.1.0/24"
  action        = "deliver"
  next_hop      = "10.240.0.21"
}

# ------------------------------------------------------------------------------
# 7. Génération de l'Inventory (Contrat d'interface)
# ------------------------------------------------------------------------------
resource "local_file" "inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    provider          = "ibmcloud"
    region            = var.region
    zone              = var.zone
    jumpbox_public_ip = ibm_is_floating_ip.jumpbox_fip.address
    server_public_ip  = ibm_is_floating_ip.server_fip.address
    node_0_public_ip  = ibm_is_floating_ip.node_0_fip.address
    node_1_public_ip  = ibm_is_floating_ip.node_1_fip.address
    jumpbox_private_ip = "10.240.0.10"
    server_private_ip  = "10.240.0.11"
    node_0_private_ip  = "10.240.0.20"
    node_1_private_ip  = "10.240.0.21"
    pod_cidr          = var.pod_cidr
    service_cidr      = var.service_cidr
    cluster_dns       = var.cluster_dns
    ssh_user          = var.ssh_user
    ssh_key_path      = replace(var.ssh_public_key_path, ".pub", "")
  })
  filename = "${path.module}/../../inventories/ibmcloud/inventory.env"
}
