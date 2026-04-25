#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"

configure_worker() {
  worker="$1"; podcidr="$2"
  ssh_vm "$worker" "sudo mkdir -p /var/lib/kubelet /var/lib/kube-proxy /etc/cni/net.d /opt/cni/bin /var/lib/kubelet/pki
sudo tee /var/lib/kubelet/kubelet-config.yaml > /dev/null <<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: /var/lib/kubernetes/ca.pem
authorization:
  mode: Webhook
clusterDomain: cluster.local
clusterDNS:
  - 10.32.0.10
containerRuntimeEndpoint: unix:///var/run/containerd/containerd.sock
cgroupDriver: systemd
podCIDR: ${podcidr}
resolvConf: /etc/resolv.conf
runtimeRequestTimeout: 15m
serverTLSBootstrap: true
EOF
sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml > /dev/null <<EOF
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: /var/lib/kube-proxy/kubeconfig
mode: iptables
clusterCIDR: 10.200.0.0/16
EOF
sudo tee /etc/cni/net.d/10-bridge.conf > /dev/null <<EOF
{
  \"cniVersion\": \"1.0.0\",
  \"name\": \"bridge\",
  \"type\": \"bridge\",
  \"bridge\": \"cnio0\",
  \"isGateway\": true,
  \"ipMasq\": true,
  \"ipam\": {
    \"type\": \"host-local\",
    \"ranges\": [[{ \"subnet\": \"${podcidr}\" }]],
    \"routes\": [{ \"dst\": \"0.0.0.0/0\" }]
  }
}
EOF
sudo tee /etc/cni/net.d/99-loopback.conf > /dev/null <<EOF
{
  \"cniVersion\": \"1.0.0\",
  \"name\": \"lo\",
  \"type\": \"loopback\"
}
EOF
grep -q 'kubernetes.local' /etc/hosts || echo '192.168.56.11 kubernetes.local' | sudo tee -a /etc/hosts
"
}
configure_worker worker-0 "$WORKER_0_POD_CIDR"
configure_worker worker-1 "$WORKER_1_POD_CIDR"
