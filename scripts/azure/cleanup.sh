#!/usr/bin/env bash
# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Script: cleanup.sh (Azure)
# Description: Wrapper script pour détruire l'infrastructure Azure via Terraform
# Auteur: Zidane Djamal
# ==============================================================================

set -euo pipefail

cd "$(dirname "$0")/../../terraform/azure"

echo "=== Destruction de l'infrastructure Azure ==="
echo "⚠️  ATTENTION : Cette action est irréversible."
read -p "Êtes-vous sûr de vouloir continuer ? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Opération annulée."
    exit 1
fi

echo ">> Destruction des ressources..."
terraform destroy -auto-approve

echo "✅ Destruction terminée."
rm -f ../../inventories/azure/inventory.env
echo "Fichier inventory.env supprimé."
