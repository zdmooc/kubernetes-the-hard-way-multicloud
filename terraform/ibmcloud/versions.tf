# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Provider: IBM Cloud
# Fichier: versions.tf
# Auteur: Zidane Djamal
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~> 1.60"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}
