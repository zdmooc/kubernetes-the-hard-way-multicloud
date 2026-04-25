#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"

kubectl --kubeconfig "$KUBECONFIG_ADMIN" create clusterrolebinding kube-apiserver-to-kubelet \
  --clusterrole=system:kubelet-api-admin \
  --user=kubernetes \
  --dry-run=client -o yaml | kubectl --kubeconfig "$KUBECONFIG_ADMIN" apply -f -

kubectl --kubeconfig "$KUBECONFIG_ADMIN" create clusterrolebinding system:kube-proxy \
  --clusterrole=system:node-proxier \
  --user=system:kube-proxy \
  --dry-run=client -o yaml | kubectl --kubeconfig "$KUBECONFIG_ADMIN" apply -f -
