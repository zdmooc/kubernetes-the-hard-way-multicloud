#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"

chmod 600 ~/.ssh/*.key

for host in "${controllers[@]}" "${workers[@]}"; do
  echo "===== ${host} ====="
  ssh_vm "$host" "hostname"
done
