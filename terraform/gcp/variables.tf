# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Provider: Google Cloud Platform (GCP)
# Fichier: variables.tf
# Auteur: Zidane Djamal
# ==============================================================================

variable "project_id" {
  description = "ID du projet GCP dans lequel déployer les ressources"
  type        = string
}

variable "region" {
  description = "Région GCP pour le déploiement"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "Zone GCP pour le déploiement des instances"
  type        = string
  default     = "europe-west1-b"
}

variable "machine_type" {
  description = "Type d'instance Compute Engine"
  type        = string
  default     = "e2-standard-2"
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
