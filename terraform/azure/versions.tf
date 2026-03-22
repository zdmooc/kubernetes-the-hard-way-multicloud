# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Provider: Microsoft Azure
# Fichier: versions.tf
# Auteur: Zidane Djamal
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}
