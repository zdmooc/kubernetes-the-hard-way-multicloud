#!/usr/bin/env bash
# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Script: render-inventory.sh
# Description: Helper script to validate the loaded inventory variables
# Auteur: Zidane Djamal
# ==============================================================================

set -euo pipefail

echo "=== Validation de l'inventaire en cours d'utilisation ==="

REQUIRED_VARS=(
  "PROVIDER" "REGION"
  "SERVER_PUBLIC_IP" "NODE_0_PUBLIC_IP" "NODE_1_PUBLIC_IP"
  "SERVER_PRIVATE_IP" "NODE_0_PRIVATE_IP" "NODE_1_PRIVATE_IP"
  "POD_CIDR" "SERVICE_CIDR" "CLUSTER_DNS"
  "KUBERNETES_VERSION" "SSH_USER" "SSH_KEY_PATH"
)

MISSING_VARS=0

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "❌ Variable manquante : $var"
    MISSING_VARS=$((MISSING_VARS + 1))
  fi
done

if [ "$MISSING_VARS" -gt 0 ]; then
  echo ""
  echo "Erreur: Le fichier d'inventaire sourcé est incomplet."
  exit 1
fi

echo "✅ Inventaire valide."
echo ""
echo "Configuration active :"
echo "- Provider : $PROVIDER"
echo "- Région   : $REGION"
echo "- Version  : $KUBERNETES_VERSION"
echo "- SSH User : $SSH_USER"
echo "- API Pub  : $SERVER_PUBLIC_IP"

exit 0
