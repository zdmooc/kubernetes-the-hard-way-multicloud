#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"
cd "$KTHW_HOME/certs"

for worker in worker-0 worker-1; do
  IP="$(ip_for "$worker")"
  cat > "${worker}-csr.json" <<EOF
{
  "CN": "system:node:${worker}",
  "key": { "algo": "rsa", "size": 2048 },
  "names": [{ "C": "FR", "L": "Paris", "O": "system:nodes", "OU": "KTHW", "ST": "IDF" }]
}
EOF
  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname="${worker},${IP}" -profile=kubernetes "${worker}-csr.json" | cfssljson -bare "${worker}"
done
