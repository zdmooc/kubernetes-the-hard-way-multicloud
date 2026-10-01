# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Provider: Microsoft Azure
# Fichier: variables.tf
# Auteur: Zidane Djamal
# ==============================================================================

variable "location" {
  description = "Région Azure pour le déploiement"
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Nom du Resource Group"
  type        = string
  default     = "k8s-thw-rg"
}

variable "vm_size" {
  description = "Taille des Virtual Machines"
  type        = string
  default     = "Standard_B2s"
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

variable "admin_cidr" {
  description = "CIDR administrateur autorisé pour SSH et API Kubernetes (ex: 203.0.113.10/32)"
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "admin_cidr doit être un CIDR valide et ne peut pas être 0.0.0.0/0."
  }
}
