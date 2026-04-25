# Scripts On-Prem Vagrant – Pré-PKI

Ce pack couvre uniquement la fondation avant PKI :

1. génération d’inventaire
2. propagation `/etc/hosts`
3. préparation kernel/sysctl/swap
4. installation des binaires
5. vérification
6. collecte des preuves

## Ordre d’exécution

Depuis `platforms/onprem/vagrant` :

```bash
bash ../../../scripts/onprem/generate-inventory.sh
bash ../../../scripts/onprem/update-hosts.sh
bash ../../../scripts/onprem/prepare-hosts.sh
bash ../../../scripts/onprem/install-binaries.sh
bash ../../../scripts/onprem/verify-foundation.sh
bash ../../../scripts/onprem/collect-evidence.sh
```

## Étape suivante

PKI :
- CA
- certificats admin / API server / etcd / service-account / workers
- kubeconfigs



[OK] Infra Vagrant + réseau
[OK] /etc/hosts + DNS local
[OK] Kernel + sysctl
[OK] containerd
[OK] binaires Kubernetes

⬇️ RESTE À FAIRE ⬇️

1. PKI (certificats)
2. Kubeconfigs
3. etcd HA
4. Control Plane HA
5. Workers (kubelet + kube-proxy)
6. Réseau Pods (CNI)
7. DNS (CoreDNS)
8. Tests + validation
9. Hardening + audit

1️⃣ PKI (CRITIQUE)

👉 Tu vas créer :

CA (root)
certificats :
admin
kube-apiserver
etcd
service-account
kubelet (workers)

👉 Résultat attendu :

ca.pem
ca-key.pem
kubernetes.pem
etcd.pem
worker-0.pem
worker-1.pem
...

👉 C’est le socle de sécurité du cluster.

2️⃣ Kubeconfigs

👉 Générer :

admin.kubeconfig
controller-manager.kubeconfig
scheduler.kubeconfig
worker-0.kubeconfig
worker-1.kubeconfig

👉 Objectif :

permettre à chaque composant de parler à l’API
3️⃣ etcd HA (3 nodes)

👉 Sur :

controller-0
controller-1
controller-2

👉 À configurer :

cluster etcd (peer URLs)
TLS obligatoire
data dir /var/lib/etcd

👉 Résultat attendu :

etcdctl member list
4️⃣ Control Plane HA

👉 Sur les 3 controllers :

kube-apiserver
kube-controller-manager
kube-scheduler

👉 Points clés :

TLS
etcd endpoint
service CIDR

API accessible via :

https://kubernetes.local:6443
5️⃣ Workers

👉 Sur worker-0 et worker-1 :

kubelet
kube-proxy

👉 kubelet doit :

pointer vers API server
utiliser containerd
avoir son certificat

👉 Résultat attendu :

kubectl get nodes
6️⃣ Réseau Pods (CNI)

👉 Sans ça = cluster inutilisable

Tu dois installer :

bridge
host-local
loopback

👉 ou plus simple ensuite :

Calico / Cilium (option moderne)

👉 Résultat attendu :

kubectl get pods -A
7️⃣ DNS (CoreDNS)

👉 Déployer CoreDNS

👉 Permet :

curl http://service-name.namespace.svc.cluster.local
8️⃣ Smoke tests (validation)

👉 Tu dois valider :

API OK
nodes Ready
pods OK
réseau OK

Tests :

kubectl run nginx --image=nginx
kubectl expose pod nginx --port=80
kubectl exec -it nginx -- curl localhost
9️⃣ Hardening + Audit (niveau expert)

👉 Là tu passes en mode architecte

À vérifier :

🔐 sécurité
RBAC strict
certificats rotation
TLS partout
etcd sécurisé
🌐 réseau
pas de 0.0.0.0/0
NetworkPolicies
⚙️ cluster
logs activés
audit logs API server
kubelet sécurisé
📊 audit readiness
kube-bench (CIS)
kube-hunter
review configs
🎯 Résultat final attendu
kubectl get nodes
NAME           STATUS   ROLES
controller-0   Ready    control-plane
controller-1   Ready    control-plane
controller-2   Ready    control-plane
worker-0       Ready    <none>
worker-1       Ready    <none>
⚠️ Point important

👉 Ton cluster est actuellement :

Infra READY
Cluster = 0%

👉 Après PKI + etcd + control plane :

Cluster = 70%

👉 Après workers + réseau :

Cluster = 100%

👉 Après audit :

Architecte Kubernetes niveau N3
🚀 Prochaine étape