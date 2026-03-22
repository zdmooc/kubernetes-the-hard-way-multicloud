# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Provider: IBM Cloud
# Fichier: variables.tf
# Auteur: Zidane Djamal
# ==============================================================================

variable "ibmcloud_api_key" {
  description = "Clé API IBM Cloud"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Région IBM Cloud pour le déploiement"
  type        = string
  default     = "eu-de"
}

variable "zone" {
  description = "Zone IBM Cloud pour le déploiement des instances"
  type        = string
  default     = "eu-de-1"
}

variable "profile" {
  description = "Profil de calcul (taille de l'instance)"
  type        = string
  default     = "bx2-2x8"
}

variable "ssh_key_name" {
  description = "Nom de la clé SSH enregistrée dans IBM Cloud VPC"
  type        = string
}

variable "ssh_user" {
  description = "Nom de l'utilisateur SSH (root par défaut sur les images minimales IBM)"
  type        = string
  default     = "root"
}

variable "ssh_public_key_path" {
  description = "Chemin local vers la clé publique SSH"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
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
