# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Provider: Google Cloud Platform (GCP)
# Fichier: main.tf
# Auteur: Zidane Djamal
# ==============================================================================

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ------------------------------------------------------------------------------
# 1. Réseau (VPC & Subnet)
# ------------------------------------------------------------------------------
resource "google_compute_network" "k8s_vpc" {
  name                    = "k8s-thw-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "k8s_subnet" {
  name          = "k8s-thw-subnet"
  network       = google_compute_network.k8s_vpc.id
  ip_cidr_range = "10.240.0.0/24"
  region        = var.region
}

# ------------------------------------------------------------------------------
# 2. Règles de Pare-feu (Firewall Rules)
# ------------------------------------------------------------------------------
resource "google_compute_firewall" "k8s_allow_internal" {
  name    = "k8s-thw-allow-internal"
  network = google_compute_network.k8s_vpc.name

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.240.0.0/24", "10.200.0.0/16"]
}

resource "google_compute_firewall" "k8s_allow_external" {
  name    = "k8s-thw-allow-external"
  network = google_compute_network.k8s_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}

# ------------------------------------------------------------------------------
# 3. Adresses IP Publiques Statiques
# ------------------------------------------------------------------------------
resource "google_compute_address" "jumpbox_ip" {
  name   = "k8s-thw-jumpbox-ip"
  region = var.region
}

resource "google_compute_address" "server_ip" {
  name   = "k8s-thw-server-ip"
  region = var.region
}

resource "google_compute_address" "node_0_ip" {
  name   = "k8s-thw-node-0-ip"
  region = var.region
}

resource "google_compute_address" "node_1_ip" {
  name   = "k8s-thw-node-1-ip"
  region = var.region
}

# ------------------------------------------------------------------------------
# 4. Instances Compute Engine (VMs)
# ------------------------------------------------------------------------------
# Note : can_ip_forward = true est requis pour le routage des pods sur les workers

resource "google_compute_instance" "jumpbox" {
  name         = "jumpbox"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["k8s-thw", "jumpbox"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.k8s_subnet.id
    network_ip = "10.240.0.10"
    access_config {
      nat_ip = google_compute_address.jumpbox_ip.address
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
  }
}

resource "google_compute_instance" "server" {
  name         = "server"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["k8s-thw", "controller"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.k8s_subnet.id
    network_ip = "10.240.0.11"
    access_config {
      nat_ip = google_compute_address.server_ip.address
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
  }
}

resource "google_compute_instance" "node_0" {
  name           = "node-0"
  machine_type   = var.machine_type
  zone           = var.zone
  tags           = ["k8s-thw", "worker"]
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.k8s_subnet.id
    network_ip = "10.240.0.20"
    access_config {
      nat_ip = google_compute_address.node_0_ip.address
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
    pod-cidr = "10.200.0.0/24"
  }
}

resource "google_compute_instance" "node_1" {
  name           = "node-1"
  machine_type   = var.machine_type
  zone           = var.zone
  tags           = ["k8s-thw", "worker"]
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.k8s_subnet.id
    network_ip = "10.240.0.21"
    access_config {
      nat_ip = google_compute_address.node_1_ip.address
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
    pod-cidr = "10.200.1.0/24"
  }
}

# ------------------------------------------------------------------------------
# 5. Routes statiques pour le trafic des Pods
# ------------------------------------------------------------------------------
resource "google_compute_route" "k8s_route_node_0" {
  name        = "k8s-thw-route-node-0"
  network     = google_compute_network.k8s_vpc.name
  next_hop_ip = "10.240.0.20"
  dest_range  = "10.200.0.0/24"
  depends_on  = [google_compute_subnetwork.k8s_subnet]
}

resource "google_compute_route" "k8s_route_node_1" {
  name        = "k8s-thw-route-node-1"
  network     = google_compute_network.k8s_vpc.name
  next_hop_ip = "10.240.0.21"
  dest_range  = "10.200.1.0/24"
  depends_on  = [google_compute_subnetwork.k8s_subnet]
}

# ------------------------------------------------------------------------------
# 6. Génération de l'Inventory (Contrat d'interface)
# ------------------------------------------------------------------------------
resource "local_file" "inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    provider           = "gcp"
    region             = var.region
    zone               = var.zone
    jumpbox_public_ip  = google_compute_address.jumpbox_ip.address
    server_public_ip   = google_compute_address.server_ip.address
    node_0_public_ip   = google_compute_address.node_0_ip.address
    node_1_public_ip   = google_compute_address.node_1_ip.address
    jumpbox_private_ip = "10.240.0.10"
    server_private_ip  = "10.240.0.11"
    node_0_private_ip  = "10.240.0.20"
    node_1_private_ip  = "10.240.0.21"
    pod_cidr           = var.pod_cidr
    service_cidr       = var.service_cidr
    cluster_dns        = var.cluster_dns
    ssh_user           = var.ssh_user
    ssh_key_path       = replace(var.ssh_public_key_path, ".pub", "")
  })
  filename = "${path.module}/../../inventories/gcp/inventory.env"
}
