#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"

for controller in "${controllers[@]}"; do
  IP="$(ip_for "$controller")"
  ssh_vm "$controller" "sudo tee /etc/systemd/system/etcd.service > /dev/null <<EOF
[Unit]
Description=etcd
After=network.target

[Service]
ExecStart=/usr/local/bin/etcd \
  --name ${controller} \
  --cert-file=/var/lib/etcd/etcd.pem \
  --key-file=/var/lib/etcd/etcd-key.pem \
  --peer-cert-file=/var/lib/etcd/etcd.pem \
  --peer-key-file=/var/lib/etcd/etcd-key.pem \
  --trusted-ca-file=/var/lib/etcd/ca.pem \
  --peer-trusted-ca-file=/var/lib/etcd/ca.pem \
  --client-cert-auth \
  --peer-client-cert-auth \
  --initial-advertise-peer-urls https://${IP}:2380 \
  --listen-peer-urls https://${IP}:2380 \
  --listen-client-urls https://${IP}:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://${IP}:2379 \
  --initial-cluster controller-0=https://192.168.56.11:2380,controller-1=https://192.168.56.12:2380,controller-2=https://192.168.56.13:2380 \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now etcd
sleep 3
sudo systemctl is-active etcd
"
done
