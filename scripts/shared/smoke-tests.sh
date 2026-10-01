#!/usr/bin/env bash
set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG_PATH:-admin.kubeconfig}"

echo "=== Kubernetes smoke tests ==="

echo ">> Nodes"
kubectl --kubeconfig "$KUBECONFIG_PATH" get nodes -o wide

echo ">> API server readiness"
kubectl --kubeconfig "$KUBECONFIG_PATH" get --raw='/readyz?verbose'
echo

echo ">> API server liveness"
kubectl --kubeconfig "$KUBECONFIG_PATH" get --raw='/livez?verbose'
echo

echo ">> Workload"
kubectl --kubeconfig "$KUBECONFIG_PATH" create deployment nginx   --image=nginx:stable-alpine   --dry-run=client -o yaml | kubectl --kubeconfig "$KUBECONFIG_PATH" apply -f -
kubectl --kubeconfig "$KUBECONFIG_PATH" wait   --for=condition=available --timeout=120s deployment/nginx

echo ">> Service"
kubectl --kubeconfig "$KUBECONFIG_PATH" expose deployment nginx   --port 80 --type NodePort   --dry-run=client -o yaml | kubectl --kubeconfig "$KUBECONFIG_PATH" apply -f -
kubectl --kubeconfig "$KUBECONFIG_PATH" get deployment,pod,service -o wide

echo "KTHW_MULTICLOUD_K8S_SMOKE=PASS"
