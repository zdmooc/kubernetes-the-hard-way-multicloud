#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"

HOSTS_CONTENT='127.0.0.1 localhost
127.0.1.1 vagrant
192.168.56.10 jumpbox
192.168.56.11 controller-0 kubernetes.local
192.168.56.12 controller-1
192.168.56.13 controller-2
192.168.56.21 worker-0
192.168.56.22 worker-1
'

sudo tee /etc/hosts >/dev/null <<< "$HOSTS_CONTENT"

for host in "${controllers[@]}" "${workers[@]}"; do
  echo "===== /etc/hosts ${host} ====="
  ssh_vm "$host" "sudo tee /etc/hosts >/dev/null" <<< "$HOSTS_CONTENT"
done

getent hosts kubernetes.local controller-0 controller-1 controller-2 worker-0 worker-1
