# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Provider: Microsoft Azure
# Fichier: outputs.tf
# Auteur: Zidane Djamal
# ==============================================================================

output "jumpbox_public_ip" {
  description = "Adresse IP publique de la Jumpbox"
  value       = azurerm_public_ip.jumpbox_pip.ip_address
}

output "server_public_ip" {
  description = "Adresse IP publique du nœud Server (Control Plane)"
  value       = azurerm_public_ip.server_pip.ip_address
}

output "node_0_public_ip" {
  description = "Adresse IP publique du Worker 0"
  value       = azurerm_public_ip.node_0_pip.ip_address
}

output "node_1_public_ip" {
  description = "Adresse IP publique du Worker 1"
  value       = azurerm_public_ip.node_1_pip.ip_address
}

output "ssh_command" {
  description = "Commande SSH pour se connecter à la Jumpbox"
  value       = "ssh -i ${replace(var.ssh_public_key_path, ".pub", "")} ${var.ssh_user}@${azurerm_public_ip.jumpbox_pip.ip_address}"
}
