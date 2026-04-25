#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"
for controller in "${controllers[@]}"; do
  ssh_vm "$controller" "sudo tee /etc/systemd/system/kube-scheduler.service > /dev/null <<EOF
[Unit]
Description=Kubernetes Scheduler
After=network.target kube-apiserver.service
[Service]
ExecStart=/usr/local/bin/kube-scheduler \
  --kubeconfig=/var/lib/kubernetes/kube-scheduler.kubeconfig \
  --leader-elect=true \
  --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now kube-scheduler
sleep 3
sudo systemctl is-active kube-scheduler
"
done
