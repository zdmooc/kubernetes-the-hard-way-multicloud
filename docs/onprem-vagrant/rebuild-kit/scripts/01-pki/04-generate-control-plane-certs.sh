#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"
cd "$KTHW_HOME/certs"

cat > kubernetes-csr.json <<'EOF'
{
  "CN": "kubernetes",
  "key": { "algo": "rsa", "size": 2048 },
  "names": [{ "C": "FR", "L": "Paris", "O": "Kubernetes", "OU": "KTHW", "ST": "IDF" }]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
  -hostname="kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster.local,kubernetes.local,10.32.0.1,192.168.56.11,192.168.56.12,192.168.56.13,127.0.0.1" \
  -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes

cat > etcd-csr.json <<'EOF'
{
  "CN": "etcd",
  "key": { "algo": "rsa", "size": 2048 },
  "names": [{ "C": "FR", "L": "Paris", "O": "etcd", "OU": "KTHW", "ST": "IDF" }]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
  -hostname="controller-0,controller-1,controller-2,192.168.56.11,192.168.56.12,192.168.56.13,127.0.0.1" \
  -profile=kubernetes etcd-csr.json | cfssljson -bare etcd
