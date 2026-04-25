#!/usr/bin/env bash
set -euo pipefail

export K8S_VERSION="${K8S_VERSION:-v1.32.0}"
export KTHW_HOME="${KTHW_HOME:-$HOME/kthw}"
export KUBECONFIG_ADMIN="${KTHW_HOME}/kubeconfigs/admin.kubeconfig"
export KUBERNETES_PUBLIC_ADDRESS="${KUBERNETES_PUBLIC_ADDRESS:-kubernetes.local}"

export JUMPBOX_IP="192.168.56.10"
export CONTROLLER_0_IP="192.168.56.11"
export CONTROLLER_1_IP="192.168.56.12"
export CONTROLLER_2_IP="192.168.56.13"
export WORKER_0_IP="192.168.56.21"
export WORKER_1_IP="192.168.56.22"

export POD_CIDR="10.200.0.0/16"
export WORKER_0_POD_CIDR="10.200.0.0/24"
export WORKER_1_POD_CIDR="10.200.1.0/24"
export SERVICE_CIDR="10.32.0.0/24"
export DNS_CLUSTER_IP="10.32.0.10"

controllers=(controller-0 controller-1 controller-2)
workers=(worker-0 worker-1)
nodes=(jumpbox controller-0 controller-1 controller-2 worker-0 worker-1)

ip_for() {
  case "$1" in
    jumpbox) echo "$JUMPBOX_IP" ;;
    controller-0) echo "$CONTROLLER_0_IP" ;;
    controller-1) echo "$CONTROLLER_1_IP" ;;
    controller-2) echo "$CONTROLLER_2_IP" ;;
    worker-0) echo "$WORKER_0_IP" ;;
    worker-1) echo "$WORKER_1_IP" ;;
    *) echo "unknown host: $1" >&2; return 1 ;;
  esac
}

key_for() {
  echo "$HOME/.ssh/$1.key"
}

ssh_vm() {
  local host="$1"; shift
  ssh -i "$(key_for "$host")" -o StrictHostKeyChecking=no "vagrant@${host}" "$@"
}
