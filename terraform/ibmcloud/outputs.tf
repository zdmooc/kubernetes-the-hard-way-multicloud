# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Provider: IBM Cloud
# Fichier: outputs.tf
# Auteur: Zidane Djamal
# ==============================================================================

output "jumpbox_public_ip" {
  description = "Adresse IP publique de la Jumpbox"
  value       = ibm_is_floating_ip.jumpbox_fip.address
}

output "server_public_ip" {
  description = "Adresse IP publique du nœud Server (Control Plane)"
  value       = ibm_is_floating_ip.server_fip.address
}

output "node_0_public_ip" {
  description = "Adresse IP publique du Worker 0"
  value       = ibm_is_floating_ip.node_0_fip.address
}

output "node_1_public_ip" {
  description = "Adresse IP publique du Worker 1"
  value       = ibm_is_floating_ip.node_1_fip.address
}

output "ssh_command" {
  description = "Commande SSH pour se connecter à la Jumpbox"
  value       = "ssh -i ${replace(var.ssh_public_key_path, ".pub", "")} ${var.ssh_user}@${ibm_is_floating_ip.jumpbox_fip.address}"
}
