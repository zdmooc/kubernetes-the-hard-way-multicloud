#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"
kubectl --kubeconfig "$KUBECONFIG_ADMIN" exec busybox -- cat /etc/resolv.conf
kubectl --kubeconfig "$KUBECONFIG_ADMIN" exec busybox -- nslookup kubernetes.default.svc.cluster.local
kubectl --kubeconfig "$KUBECONFIG_ADMIN" exec busybox -- nslookup nginx.default.svc.cluster.local
kubectl --kubeconfig "$KUBECONFIG_ADMIN" exec busybox -- wget -qO- http://nginx
