#!/usr/bin/env bash
# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Script: cleanup.sh (On-Premises)
# Description: Nettoie l'environnement local (VMs et réseau virtuel)
# Auteur: Zidane Djamal
# ==============================================================================

set -euo pipefail

echo "=== Nettoyage de l'environnement On-Premises ==="
echo "⚠️  ATTENTION : Cela supprimera les VMs locales (libvirt/VirtualBox)."
read -p "Êtes-vous sûr de vouloir continuer ? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Opération annulée."
    exit 1
fi

# Logique de nettoyage selon l'hyperviseur
if command -v virsh &> /dev/null; then
  echo ">> Suppression des domaines libvirt..."
  for vm in jumpbox server node-0 node-1; do
    virsh destroy $vm || true
    virsh undefine $vm --remove-all-storage || true
  done
  
  echo ">> Suppression du réseau virtuel..."
  virsh net-destroy k8s-thw-net || true
  virsh net-undefine k8s-thw-net || true
else
  echo "⚠️ virsh non trouvé. Veuillez nettoyer manuellement votre hyperviseur."
fi

echo "✅ Nettoyage terminé."
rm -f ../../inventories/onprem/inventory.env
echo "Fichier inventory.env supprimé."
