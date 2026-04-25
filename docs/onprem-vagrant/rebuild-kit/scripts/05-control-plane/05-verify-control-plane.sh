#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"
kubectl --kubeconfig "$KUBECONFIG_ADMIN" get --raw='/version'
kubectl --kubeconfig "$KUBECONFIG_ADMIN" get componentstatuses || true
