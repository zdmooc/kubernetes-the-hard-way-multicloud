#!/usr/bin/env bash
# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Script: check-prereqs.sh
# Description: Vérifie la présence des outils nécessaires (cfssl, kubectl, etc.)
# Auteur: Zidane Djamal
# ==============================================================================

set -euo pipefail

echo "=== Vérification des prérequis système ==="

# Liste des commandes requises
REQUIRED_CMDS=("cfssl" "cfssljson" "kubectl" "ssh" "scp" "openssl")

MISSING_CMDS=0

for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "❌ Erreur: L'outil '$cmd' n'est pas installé ou n'est pas dans le PATH."
    MISSING_CMDS=$((MISSING_CMDS + 1))
  else
    echo "✅ $cmd est installé ($(command -v $cmd))"
  fi
done

if [ "$MISSING_CMDS" -gt 0 ]; then
  echo ""
  echo "Veuillez installer les outils manquants avant de continuer."
  echo "Consultez docs/core/01-prerequisites.md pour les instructions."
  exit 1
fi

echo "✅ Tous les prérequis sont satisfaits."
exit 0
