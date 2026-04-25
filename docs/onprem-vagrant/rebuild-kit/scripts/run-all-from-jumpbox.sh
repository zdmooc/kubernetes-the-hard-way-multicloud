#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

bash "$ROOT/scripts/00-bootstrap/01-hosts-all.sh"
bash "$ROOT/scripts/00-bootstrap/02-install-client-tools.sh"
bash "$ROOT/scripts/00-bootstrap/03-test-ssh.sh"
bash "$ROOT/scripts/00-bootstrap/04-prepare-hosts.sh"

bash "$ROOT/scripts/01-pki/01-generate-ca.sh"
bash "$ROOT/scripts/01-pki/02-generate-client-certs.sh"
bash "$ROOT/scripts/01-pki/03-generate-worker-certs.sh"
bash "$ROOT/scripts/01-pki/04-generate-control-plane-certs.sh"
bash "$ROOT/scripts/01-pki/05-verify-certs.sh"

bash "$ROOT/scripts/02-kubeconfigs/01-generate-kubeconfigs.sh"
bash "$ROOT/scripts/02-kubeconfigs/02-generate-encryption-config.sh"

bash "$ROOT/scripts/03-distribute/01-distribute-to-controllers.sh"
bash "$ROOT/scripts/03-distribute/02-distribute-to-workers.sh"

bash "$ROOT/scripts/04-etcd/01-bootstrap-etcd.sh"
bash "$ROOT/scripts/04-etcd/02-verify-etcd.sh"

bash "$ROOT/scripts/05-control-plane/01-bootstrap-apiserver.sh"
bash "$ROOT/scripts/05-control-plane/02-bootstrap-controller-manager.sh"
bash "$ROOT/scripts/05-control-plane/03-bootstrap-scheduler.sh"
bash "$ROOT/scripts/05-control-plane/04-rbac-control-plane.sh"
bash "$ROOT/scripts/05-control-plane/05-verify-control-plane.sh"

bash "$ROOT/scripts/06-workers/01-configure-workers.sh"
bash "$ROOT/scripts/06-workers/02-bootstrap-workers.sh"
bash "$ROOT/scripts/06-workers/03-approve-kubelet-csr.sh"
bash "$ROOT/scripts/06-workers/04-fix-pod-routes.sh"
bash "$ROOT/scripts/06-workers/05-verify-workers.sh"

bash "$ROOT/scripts/07-addons/01-deploy-coredns.sh"
bash "$ROOT/scripts/08-tests/01-smoke-test-nginx-busybox.sh"
bash "$ROOT/scripts/08-tests/02-smoke-test-dns-http.sh"
bash "$ROOT/scripts/09-evidence/01-collect-evidence.sh"
