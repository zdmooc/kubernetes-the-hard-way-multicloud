# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Provider: Amazon Web Services (AWS)
# Fichier: outputs.tf
# Auteur: Zidane Djamal
# ==============================================================================

output "jumpbox_public_ip" {
  description = "Adresse IP publique de la Jumpbox"
  value       = aws_instance.jumpbox.public_ip
}

output "server_public_ip" {
  description = "Adresse IP publique du nœud Server (Control Plane)"
  value       = aws_instance.server.public_ip
}

output "node_0_public_ip" {
  description = "Adresse IP publique du Worker 0"
  value       = aws_instance.node_0.public_ip
}

output "node_1_public_ip" {
  description = "Adresse IP publique du Worker 1"
  value       = aws_instance.node_1.public_ip
}

output "ssh_command" {
  description = "Commande SSH pour se connecter à la Jumpbox"
  value       = "ssh -i ${replace(var.ssh_public_key_path, ".pub", "")} ${var.ssh_user}@${aws_instance.jumpbox.public_ip}"
}
