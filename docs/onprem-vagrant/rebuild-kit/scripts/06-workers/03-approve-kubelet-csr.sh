#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"
sleep 10
pending="$(kubectl --kubeconfig "$KUBECONFIG_ADMIN" get csr --no-headers 2>/dev/null | awk '$NF=="Pending"{print $1}' || true)"
[ -n "$pending" ] && kubectl --kubeconfig "$KUBECONFIG_ADMIN" certificate approve $pending || true
kubectl --kubeconfig "$KUBECONFIG_ADMIN" get csr
