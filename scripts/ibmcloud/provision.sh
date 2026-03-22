#!/usr/bin/env bash
# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Script: provision.sh (IBM Cloud)
# Description: Wrapper script pour provisionner l'infrastructure IBM Cloud via Terraform
# Auteur: Zidane Djamal
# ==============================================================================

set -euo pipefail

cd "$(dirname "$0")/../../terraform/ibmcloud"

echo "=== Provisionnement de l'infrastructure IBM Cloud ==="

if [ ! -f "terraform.tfvars" ]; then
  echo "❌ Erreur: Le fichier terraform.tfvars est manquant."
  echo "Veuillez copier terraform.tfvars.example vers terraform.tfvars et le configurer (ibmcloud_api_key)."
  exit 1
fi

echo ">> Initialisation de Terraform..."
terraform init

echo ">> Application de la configuration..."
terraform apply -auto-approve

echo "✅ Provisionnement terminé avec succès."
echo "Le fichier inventory.env a été généré dans inventories/ibmcloud/."
