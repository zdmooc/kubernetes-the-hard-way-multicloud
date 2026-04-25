#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../env.sh"
cd "$KTHW_HOME/certs"
ls -1 *.pem | sort
openssl x509 -in kubernetes.pem -text -noout | grep -A2 "Subject Alternative Name"
openssl x509 -in etcd.pem -text -noout | grep -A2 "Subject Alternative Name"
openssl x509 -in worker-0.pem -text -noout | grep -A2 "Subject Alternative Name"
