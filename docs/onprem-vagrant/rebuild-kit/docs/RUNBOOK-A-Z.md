# RUNBOOK A-Z — Reconstruction complète

## 0. Depuis le PC Windows Git Bash

```bash
cd /c/workspaces/Expert_kubernetes/04/kubernetes-the-hard-way-multicloud/platforms/onprem/vagrant

vagrant destroy -f
vagrant up
vagrant status
```

Uploader les clés SSH Vagrant vers jumpbox :

```bash
MSYS_NO_PATHCONV=1 vagrant upload .vagrant/machines/controller-0/virtualbox/private_key /home/vagrant/.ssh/controller-0.key jumpbox
MSYS_NO_PATHCONV=1 vagrant upload .vagrant/machines/controller-1/virtualbox/private_key /home/vagrant/.ssh/controller-1.key jumpbox
MSYS_NO_PATHCONV=1 vagrant upload .vagrant/machines/controller-2/virtualbox/private_key /home/vagrant/.ssh/controller-2.key jumpbox
MSYS_NO_PATHCONV=1 vagrant upload .vagrant/machines/worker-0/virtualbox/private_key /home/vagrant/.ssh/worker-0.key jumpbox
MSYS_NO_PATHCONV=1 vagrant upload .vagrant/machines/worker-1/virtualbox/private_key /home/vagrant/.ssh/worker-1.key jumpbox
```

Copier ce dossier complet dans la jumpbox sous :

```bash
~/kthw-rebuild
```

Puis :

```bash
vagrant ssh jumpbox
```

## 1. Depuis jumpbox

```bash
cd ~/kthw-rebuild

bash scripts/00-bootstrap/01-hosts-all.sh
bash scripts/00-bootstrap/02-install-client-tools.sh
bash scripts/00-bootstrap/03-test-ssh.sh
bash scripts/00-bootstrap/04-prepare-hosts.sh

bash scripts/01-pki/01-generate-ca.sh
bash scripts/01-pki/02-generate-client-certs.sh
bash scripts/01-pki/03-generate-worker-certs.sh
bash scripts/01-pki/04-generate-control-plane-certs.sh
bash scripts/01-pki/05-verify-certs.sh

bash scripts/02-kubeconfigs/01-generate-kubeconfigs.sh
bash scripts/02-kubeconfigs/02-generate-encryption-config.sh

bash scripts/03-distribute/01-distribute-to-controllers.sh
bash scripts/03-distribute/02-distribute-to-workers.sh

bash scripts/04-etcd/01-bootstrap-etcd.sh
bash scripts/04-etcd/02-verify-etcd.sh

bash scripts/05-control-plane/01-bootstrap-apiserver.sh
bash scripts/05-control-plane/02-bootstrap-controller-manager.sh
bash scripts/05-control-plane/03-bootstrap-scheduler.sh
bash scripts/05-control-plane/04-rbac-control-plane.sh
bash scripts/05-control-plane/05-verify-control-plane.sh

bash scripts/06-workers/01-configure-workers.sh
bash scripts/06-workers/02-bootstrap-workers.sh
bash scripts/06-workers/03-approve-kubelet-csr.sh
bash scripts/06-workers/04-fix-pod-routes.sh
bash scripts/06-workers/05-verify-workers.sh

bash scripts/07-addons/01-deploy-coredns.sh

bash scripts/08-tests/01-smoke-test-nginx-busybox.sh
bash scripts/08-tests/02-smoke-test-dns-http.sh

bash scripts/09-evidence/01-collect-evidence.sh
```

## Alternative : exécution globale

```bash
bash scripts/run-all-from-jumpbox.sh
```

## Résultat attendu

```text
worker-0 Ready
worker-1 Ready
CoreDNS Running
nginx Running
busybox Running
DNS OK
HTTP nginx OK
kubectl exec OK
```
