#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"

for controller in "${controllers[@]}"; do
  IP="$(ip_for "$controller")"
  ssh_vm "$controller" "sudo tee /etc/systemd/system/kube-apiserver.service > /dev/null <<EOF
[Unit]
Description=Kubernetes API Server
After=network.target

[Service]
ExecStart=/usr/local/bin/kube-apiserver \
  --advertise-address=${IP} \
  --allow-privileged=true \
  --apiserver-count=3 \
  --authorization-mode=Node,RBAC \
  --bind-address=0.0.0.0 \
  --client-ca-file=/var/lib/kubernetes/ca.pem \
  --enable-admission-plugins=NodeRestriction \
  --enable-bootstrap-token-auth=true \
  --etcd-cafile=/var/lib/etcd/ca.pem \
  --etcd-certfile=/var/lib/etcd/etcd.pem \
  --etcd-keyfile=/var/lib/etcd/etcd-key.pem \
  --etcd-servers=https://192.168.56.11:2379,https://192.168.56.12:2379,https://192.168.56.13:2379 \
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \
  --kubelet-preferred-address-types=Hostname,InternalDNS,InternalIP,ExternalDNS,ExternalIP \
  --runtime-config=api/all=true \
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \
  --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem \
  --service-account-issuer=https://kubernetes.default.svc.cluster.local \
  --service-cluster-ip-range=10.32.0.0/24 \
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \
  --requestheader-client-ca-file=/var/lib/kubernetes/ca.pem \
  --proxy-client-cert-file=/var/lib/kubernetes/kubernetes.pem \
  --proxy-client-key-file=/var/lib/kubernetes/kubernetes-key.pem \
  --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now kube-apiserver
sleep 5
sudo systemctl is-active kube-apiserver
"
done
sudo grep -q 'kubernetes.local' /etc/hosts || echo '192.168.56.11 kubernetes.local' | sudo tee -a /etc/hosts
kubectl --kubeconfig "$KUBECONFIG_ADMIN" get --raw='/version'
