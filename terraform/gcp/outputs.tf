# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Provider: Google Cloud Platform (GCP)
# Fichier: outputs.tf
# Auteur: Zidane Djamal
# ==============================================================================

output "jumpbox_public_ip" {
  description = "Adresse IP publique de la Jumpbox"
  value       = google_compute_address.jumpbox_ip.address
}

output "server_public_ip" {
  description = "Adresse IP publique du nœud Server (Control Plane)"
  value       = google_compute_address.server_ip.address
}

output "node_0_public_ip" {
  description = "Adresse IP publique du Worker 0"
  value       = google_compute_address.node_0_ip.address
}

output "node_1_public_ip" {
  description = "Adresse IP publique du Worker 1"
  value       = google_compute_address.node_1_ip.address
}

output "ssh_command" {
  description = "Commande SSH pour se connecter à la Jumpbox"
  value       = "ssh -i ${replace(var.ssh_public_key_path, ".pub", "")} ${var.ssh_user}@${google_compute_address.jumpbox_ip.address}"
}
