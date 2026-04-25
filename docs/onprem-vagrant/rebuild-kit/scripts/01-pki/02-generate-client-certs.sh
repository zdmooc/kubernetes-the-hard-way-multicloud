#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"
cd "$KTHW_HOME/certs"

gen_client() {
  local name="$1"; local cn="$2"; local org="$3"
  cat > "${name}-csr.json" <<EOF
{
  "CN": "${cn}",
  "key": { "algo": "rsa", "size": 2048 },
  "names": [{ "C": "FR", "L": "Paris", "O": "${org}", "OU": "KTHW", "ST": "IDF" }]
}
EOF
  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes "${name}-csr.json" | cfssljson -bare "${name}"
}

gen_client admin admin system:masters
gen_client kube-controller-manager system:kube-controller-manager system:kube-controller-manager
gen_client kube-scheduler system:kube-scheduler system:kube-scheduler
gen_client kube-proxy system:kube-proxy system:node-proxier
gen_client service-account service-accounts Kubernetes
