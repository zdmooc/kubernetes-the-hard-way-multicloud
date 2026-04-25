#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"
for worker in "${workers[@]}"; do
  ssh_vm "$worker" "
    sudo iptables -P FORWARD ACCEPT
    sudo iptables -C FORWARD -s 10.200.0.0/16 -j ACCEPT 2>/dev/null || sudo iptables -I FORWARD -s 10.200.0.0/16 -j ACCEPT
    sudo iptables -C FORWARD -d 10.200.0.0/16 -j ACCEPT 2>/dev/null || sudo iptables -I FORWARD -d 10.200.0.0/16 -j ACCEPT
  "
done
ssh_vm worker-0 "sudo ip route replace 10.200.1.0/24 via 192.168.56.22 dev eth1"
ssh_vm worker-1 "sudo ip route replace 10.200.0.0/24 via 192.168.56.21 dev eth1"
