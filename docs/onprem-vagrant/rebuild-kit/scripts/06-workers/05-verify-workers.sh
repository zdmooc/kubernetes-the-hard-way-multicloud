#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"
kubectl --kubeconfig "$KUBECONFIG_ADMIN" get nodes -o wide
for worker in "${workers[@]}"; do ssh_vm "$worker" "ip route | grep 10.200 || true"; done
