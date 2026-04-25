#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"
cd "$KTHW_HOME"

for worker in "${workers[@]}"; do
  scp -i "$(key_for "$worker")" -o StrictHostKeyChecking=no \
    certs/ca.pem certs/${worker}.pem certs/${worker}-key.pem \
    kubeconfigs/${worker}.kubeconfig kubeconfigs/kube-proxy.kubeconfig \
    vagrant@${worker}:~/

  ssh_vm "$worker" "
    sudo mkdir -p /var/lib/kubernetes /var/lib/kubelet /var/lib/kube-proxy
    sudo mv ~/ca.pem /var/lib/kubernetes/
    sudo mv ~/${worker}.pem /var/lib/kubelet/kubelet.pem
    sudo mv ~/${worker}-key.pem /var/lib/kubelet/kubelet-key.pem
    sudo mv ~/${worker}.kubeconfig /var/lib/kubelet/kubeconfig
    sudo mv ~/kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
  "
done
