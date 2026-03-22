#!/usr/bin/env bash
# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Script: prepare-hosts.sh (On-Premises)
# Description: Prépare les VMs locales (désactive le swap, active l'IP forwarding)
# Auteur: Zidane Djamal
# ==============================================================================

set -euo pipefail

echo "=== Préparation des hôtes On-Premises ==="

if [ -z "${SERVER_PRIVATE_IP:-}" ]; then
  echo "❌ Erreur: L'inventaire n'est pas sourcé."
  exit 1
fi

NODES=("${SERVER_PRIVATE_IP}" "${NODE_0_PRIVATE_IP}" "${NODE_1_PRIVATE_IP}")

for node in "${NODES[@]}"; do
  echo ">> Configuration du nœud $node..."
  
  ssh -o StrictHostKeyChecking=no -i "${SSH_KEY_PATH}" "${SSH_USER}@${node}" << 'EOF'
    # Désactivation du swap (requis par kubelet)
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    # Activation de l'IP Forwarding
    echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
    sudo sysctl --system

    # Chargement des modules kernel
    cat <<EOF_MOD | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF_MOD
    sudo modprobe overlay
    sudo modprobe br_netfilter
EOF
done

echo "✅ Hôtes préparés avec succès."
