#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"

mkdir -p "$KTHW_HOME"/{certs,kubeconfigs,configs,evidence}
cd /tmp

curl -LO https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
curl -LO https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssl_linux-amd64 cfssljson_linux-amd64
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson

curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

cfssl version
kubectl version --client
