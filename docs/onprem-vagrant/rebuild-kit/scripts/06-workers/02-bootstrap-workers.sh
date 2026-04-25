#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"

for worker in "${workers[@]}"; do
  IP="$(ip_for "$worker")"
  ssh_vm "$worker" "sudo tee /etc/systemd/system/kubelet.service > /dev/null <<EOF
[Unit]
Description=Kubernetes Kubelet
After=containerd.service
Requires=containerd.service
[Service]
ExecStart=/usr/local/bin/kubelet \
  --config=/var/lib/kubelet/kubelet-config.yaml \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --hostname-override=${worker} \
  --node-ip=${IP} \
  --pod-infra-container-image=registry.k8s.io/pause:3.10 \
  --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
sudo tee /etc/systemd/system/kube-proxy.service > /dev/null <<EOF
[Unit]
Description=Kubernetes Kube Proxy
After=network.target
[Service]
ExecStart=/usr/local/bin/kube-proxy --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now kubelet kube-proxy
sleep 5
sudo systemctl is-active kubelet
sudo systemctl is-active kube-proxy
"
done
