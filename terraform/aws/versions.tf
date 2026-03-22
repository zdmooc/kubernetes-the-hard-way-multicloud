# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Provider: Amazon Web Services (AWS)
# Fichier: versions.tf
# Auteur: Zidane Djamal
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}
