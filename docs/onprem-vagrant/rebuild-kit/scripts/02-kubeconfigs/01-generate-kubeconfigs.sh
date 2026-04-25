#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"
cd "$KTHW_HOME"
mkdir -p kubeconfigs

for instance in worker-0 worker-1; do
  kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=certs/ca.pem --embed-certs=true --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 --kubeconfig=kubeconfigs/${instance}.kubeconfig
  kubectl config set-credentials system:node:${instance} --client-certificate=certs/${instance}.pem --client-key=certs/${instance}-key.pem --embed-certs=true --kubeconfig=kubeconfigs/${instance}.kubeconfig
  kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:node:${instance} --kubeconfig=kubeconfigs/${instance}.kubeconfig
  kubectl config use-context default --kubeconfig=kubeconfigs/${instance}.kubeconfig
done

for component in kube-proxy kube-controller-manager kube-scheduler; do
  SERVER="https://${KUBERNETES_PUBLIC_ADDRESS}:6443"
  [ "$component" = "kube-controller-manager" ] && SERVER="https://127.0.0.1:6443"
  [ "$component" = "kube-scheduler" ] && SERVER="https://127.0.0.1:6443"
  kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=certs/ca.pem --embed-certs=true --server=${SERVER} --kubeconfig=kubeconfigs/${component}.kubeconfig
  kubectl config set-credentials system:${component} --client-certificate=certs/${component}.pem --client-key=certs/${component}-key.pem --embed-certs=true --kubeconfig=kubeconfigs/${component}.kubeconfig
  kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:${component} --kubeconfig=kubeconfigs/${component}.kubeconfig
  kubectl config use-context default --kubeconfig=kubeconfigs/${component}.kubeconfig
done

kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=certs/ca.pem --embed-certs=true --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 --kubeconfig=kubeconfigs/admin.kubeconfig
kubectl config set-credentials admin --client-certificate=certs/admin.pem --client-key=certs/admin-key.pem --embed-certs=true --kubeconfig=kubeconfigs/admin.kubeconfig
kubectl config set-context default --cluster=kubernetes-the-hard-way --user=admin --kubeconfig=kubeconfigs/admin.kubeconfig
kubectl config use-context default --kubeconfig=kubeconfigs/admin.kubeconfig
