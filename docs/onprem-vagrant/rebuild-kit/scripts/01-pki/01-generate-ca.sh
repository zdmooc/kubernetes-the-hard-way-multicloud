#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"
cd "$KTHW_HOME/certs"

cat > ca-config.json <<'EOF'
{
  "signing": {
    "default": { "expiry": "87600h" },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "87600h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<'EOF'
{
  "CN": "Kubernetes",
  "key": { "algo": "rsa", "size": 2048 },
  "names": [{ "C": "FR", "L": "Paris", "O": "Kubernetes", "OU": "CA", "ST": "IDF" }]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca
ls -l ca*.pem
