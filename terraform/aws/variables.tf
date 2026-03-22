# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Provider: Amazon Web Services (AWS)
# Fichier: variables.tf
# Auteur: Zidane Djamal
# ==============================================================================

variable "aws_region" {
  description = "Région AWS pour le déploiement"
  type        = string
  default     = "eu-west-1"
}

variable "aws_az" {
  description = "Availability Zone AWS pour le déploiement des instances"
  type        = string
  default     = "eu-west-1a"
}

variable "instance_type_server" {
  description = "Type d'instance EC2 pour le Control Plane"
  type        = string
  default     = "t3.medium"
}

variable "instance_type_worker" {
  description = "Type d'instance EC2 pour les Workers"
  type        = string
  default     = "t3.medium"
}

variable "ssh_public_key_path" {
  description = "Chemin vers la clé publique SSH à injecter dans les instances"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_user" {
  description = "Nom de l'utilisateur SSH"
  type        = string
  default     = "ubuntu"
}

variable "pod_cidr" {
  description = "Plage CIDR globale pour les pods du cluster"
  type        = string
  default     = "10.200.0.0/16"
}

variable "service_cidr" {
  description = "Plage CIDR pour les services Kubernetes"
  type        = string
  default     = "10.32.0.0/24"
}

variable "cluster_dns" {
  description = "Adresse IP du service CoreDNS"
  type        = string
  default     = "10.32.0.10"
}
