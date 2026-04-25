#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"
kubectl --kubeconfig "$KUBECONFIG_ADMIN" delete pod busybox nginx --ignore-not-found
kubectl --kubeconfig "$KUBECONFIG_ADMIN" delete svc nginx --ignore-not-found
kubectl --kubeconfig "$KUBECONFIG_ADMIN" run nginx --image=nginx --restart=Never
kubectl --kubeconfig "$KUBECONFIG_ADMIN" expose pod nginx --port=80 --target-port=80
kubectl --kubeconfig "$KUBECONFIG_ADMIN" run busybox --image=busybox:1.36 --restart=Never -- sleep 3600
kubectl --kubeconfig "$KUBECONFIG_ADMIN" wait --for=condition=Ready pod/nginx --timeout=180s
kubectl --kubeconfig "$KUBECONFIG_ADMIN" wait --for=condition=Ready pod/busybox --timeout=180s
kubectl --kubeconfig "$KUBECONFIG_ADMIN" get pod,svc,endpoints -o wide
