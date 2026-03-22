# 07 - Déploiement du Control Plane

**Auteur :** Zidane Djamal

## Objectif
Ce chapitre couvre le déploiement des composants du plan de contrôle Kubernetes sur le nœud `server`. Le Control Plane est le cerveau du cluster. Il prend les décisions globales (comme la planification des pods) et détecte/réagit aux événements du cluster.

## Prérequis
- Le service `etcd` doit être opérationnel (Chapitre 06).
- Les certificats (Chapitre 03), les kubeconfigs (Chapitre 04) et le fichier de chiffrement (Chapitre 05) doivent être présents sur le nœud `server`.

## Entrées
- Binaires Kubernetes (API Server, Controller Manager, Scheduler).
- Variables d'inventaire (`SERVICE_CIDR`).

## Sorties
- Les services `kube-apiserver`, `kube-controller-manager` et `kube-scheduler` en cours d'exécution.
- Le RBAC configuré pour permettre à l'API Server d'interroger les Kubelets.

## Étapes

L'ensemble de ces étapes est automatisé dans le script `scripts/core/06-control-plane.sh`. Les commandes sont exécutées sur le nœud `server`.

### 1. Téléchargement des binaires

```bash
KUBERNETES_VERSION="v1.29.2"
wget -q --show-progress --https-only --timestamping \
  "https://dl.k8s.io/release/${KUBERNETES_VERSION}/bin/linux/amd64/kube-apiserver" \
  "https://dl.k8s.io/release/${KUBERNETES_VERSION}/bin/linux/amd64/kube-controller-manager" \
  "https://dl.k8s.io/release/${KUBERNETES_VERSION}/bin/linux/amd64/kube-scheduler"

chmod +x kube-apiserver kube-controller-manager kube-scheduler
sudo mv kube-apiserver kube-controller-manager kube-scheduler /usr/local/bin/
```

### 2. Configuration du kube-apiserver

L'API Server est le composant central avec lequel tous les autres communiquent.

```bash
sudo mkdir -p /var/lib/kubernetes/
sudo cp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
  service-account-key.pem service-account.pem \
  encryption-config.yaml /var/lib/kubernetes/

cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${SERVER_PRIVATE_IP} \\
  --allow-privileged=true \\
  --apiserver-count=1 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NodeRestriction,ServiceAccount \\
  --enable-bootstrap-token-auth=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://127.0.0.1:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --runtime-config='api/all=true' \\
  --service-account-issuer=https://${SERVER_PUBLIC_IP}:6443 \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### 3. Configuration du kube-controller-manager

```bash
sudo cp kube-controller-manager.kubeconfig /var/lib/kubernetes/

cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --bind-address=0.0.0.0 \\
  --cluster-cidr=${POD_CIDR} \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### 4. Configuration du kube-scheduler

```bash
sudo cp kube-scheduler.kubeconfig /var/lib/kubernetes/

cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### 5. Démarrage des services

```bash
sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
```

### 6. Configuration du RBAC pour Kubelet

L'API Server a besoin d'interroger les Kubelets (pour `kubectl logs` ou `kubectl exec`). Il faut lui en donner l'autorisation explicite.

```bash
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups: [""]
    resources: ["nodes/proxy", "nodes/stats", "nodes/log", "nodes/spec", "nodes/metrics"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
```

## Validations

Depuis la jumpbox (ou le server), utilisez le kubeconfig admin pour vérifier la santé des composants :

```bash
kubectl get componentstatuses --kubeconfig admin.kubeconfig
```
Les composants `scheduler` et `controller-manager` doivent afficher le statut `Healthy`.

## Points de vigilance
- **Paramètre `--authorization-mode=Node,RBAC` :** Le plugin `Node` est essentiel. Il limite les Kubelets (identifiés par le groupe `system:nodes`) à ne pouvoir lire que les secrets et configmaps des pods qui leur sont spécifiquement assignés.
- **Service Account Issuer :** Depuis Kubernetes 1.20+, les paramètres `--service-account-issuer` et `--service-account-signing-key-file` sont obligatoires pour la génération des tokens de Service Account (Bound Service Account Token Volume).

## Dépendances
- etcd doit être en cours d'exécution.

## Articulation avec les autres chapitres
Le Control Plane est maintenant opérationnel, mais le cluster n'a aucune capacité de calcul (aucun nœud pour exécuter des pods). Le Chapitre 08 va configurer les Workers pour qu'ils s'enregistrent auprès de cette API Server.
