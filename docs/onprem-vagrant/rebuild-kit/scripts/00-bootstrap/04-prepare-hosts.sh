#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"

REMOTE='
set -e
sudo swapoff -a || true
sudo sed -i.bak "/ swap / s/^/#/" /etc/fstab || true
cat <<EOF | sudo tee /etc/modules-load.d/kubernetes.conf >/dev/null
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes.conf >/dev/null
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system >/dev/null || true
'

for host in "${nodes[@]}"; do
  echo "===== prepare ${host} ====="
  if [ "$host" = "jumpbox" ]; then bash -lc "$REMOTE"; else ssh_vm "$host" "$REMOTE"; fi
done
