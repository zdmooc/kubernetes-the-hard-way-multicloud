# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Provider: Google Cloud Platform (GCP)
# Fichier: versions.tf
# Auteur: Zidane Djamal
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}
