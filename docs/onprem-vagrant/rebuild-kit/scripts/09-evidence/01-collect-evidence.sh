#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"
mkdir -p "$KTHW_HOME/evidence"
kubectl --kubeconfig "$KUBECONFIG_ADMIN" get nodes -o wide > "$KTHW_HOME/evidence/01-nodes.txt"
kubectl --kubeconfig "$KUBECONFIG_ADMIN" get pods -A -o wide > "$KTHW_HOME/evidence/02-pods.txt"
kubectl --kubeconfig "$KUBECONFIG_ADMIN" get svc,endpoints -A -o wide > "$KTHW_HOME/evidence/03-services-endpoints.txt"
kubectl --kubeconfig "$KUBECONFIG_ADMIN" get csr > "$KTHW_HOME/evidence/04-csr.txt"
kubectl --kubeconfig "$KUBECONFIG_ADMIN" exec busybox -- nslookup kubernetes.default.svc.cluster.local > "$KTHW_HOME/evidence/05-dns-kubernetes.txt"
kubectl --kubeconfig "$KUBECONFIG_ADMIN" exec busybox -- nslookup nginx.default.svc.cluster.local > "$KTHW_HOME/evidence/06-dns-nginx.txt"
kubectl --kubeconfig "$KUBECONFIG_ADMIN" exec busybox -- wget -qO- http://nginx > "$KTHW_HOME/evidence/07-http-nginx.html"
find "$KTHW_HOME/evidence" -type f -maxdepth 1 -print
