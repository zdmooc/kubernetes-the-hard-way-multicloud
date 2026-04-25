#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"
cd "$KTHW_HOME"

for controller in "${controllers[@]}"; do
  scp -i "$(key_for "$controller")" -o StrictHostKeyChecking=no \
    certs/ca.pem certs/ca-key.pem certs/kubernetes.pem certs/kubernetes-key.pem \
    certs/service-account.pem certs/service-account-key.pem certs/etcd.pem certs/etcd-key.pem \
    kubeconfigs/kube-controller-manager.kubeconfig kubeconfigs/kube-scheduler.kubeconfig \
    configs/encryption-config.yaml vagrant@${controller}:~/

  ssh_vm "$controller" "
    sudo mkdir -p /var/lib/kubernetes /var/lib/etcd
    sudo mv ~/ca.pem ~/ca-key.pem ~/kubernetes.pem ~/kubernetes-key.pem ~/service-account.pem ~/service-account-key.pem ~/kube-controller-manager.kubeconfig ~/kube-scheduler.kubeconfig ~/encryption-config.yaml /var/lib/kubernetes/
    sudo mv ~/etcd.pem ~/etcd-key.pem /var/lib/etcd/
    sudo cp /var/lib/kubernetes/ca.pem /var/lib/etcd/ca.pem
  "
done
