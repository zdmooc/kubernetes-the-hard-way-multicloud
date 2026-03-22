#!/usr/bin/env bash
# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Script: generate-machine-db.sh
# Description: Génère un fichier temporaire contenant le mapping IP/Hostname
# Auteur: Zidane Djamal
# ==============================================================================

set -euo pipefail

# Vérifier si l'inventaire est sourcé
if [ -z "${SERVER_PRIVATE_IP:-}" ]; then
  echo "❌ Erreur: Les variables d'environnement ne sont pas définies."
  echo "Avez-vous oublié de sourcer inventory.env ? (source inventory.env)"
  exit 1
fi

OUTPUT_FILE="machines.txt"

echo "=== Génération de la base de données des machines ($OUTPUT_FILE) ==="

cat <<EOF > "$OUTPUT_FILE"
${SERVER_PRIVATE_IP} server
${NODE_0_PRIVATE_IP} node-0
${NODE_1_PRIVATE_IP} node-1
EOF

echo "✅ Fichier $OUTPUT_FILE généré avec succès."
cat "$OUTPUT_FILE"
