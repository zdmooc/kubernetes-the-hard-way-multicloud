#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
kubectl --kubeconfig "$KUBECONFIG_ADMIN" apply -f "$ROOT/yaml/addons/coredns.yaml"
kubectl --kubeconfig "$KUBECONFIG_ADMIN" -n kube-system rollout status deployment/coredns --timeout=180s
kubectl --kubeconfig "$KUBECONFIG_ADMIN" get pods -n kube-system -o wide
