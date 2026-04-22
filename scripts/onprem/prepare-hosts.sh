#!/usr/bin/env bash
set -euo pipefail

cat <<'MSG'
Ce script est un helper minimal.
Objectif : rappeler les contrôles à faire sur les VM Vagrant avant de brancher le core Kubernetes.
MSG

for host in jumpbox controller-0 controller-1 controller-2 worker-0 worker-1; do
  echo "===== ${host} ====="
  vagrant ssh "${host}" -c 'hostnamectl; ip -brief addr; swapon --show; lsmod | egrep "overlay|br_netfilter" || true; sysctl net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables || true'
done
