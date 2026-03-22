# 08 - Déploiement des Nœuds Workers

**Auteur :** Zidane Djamal

## Objectif
Ce chapitre explique comment configurer les nœuds workers (`node-0` et `node-1`). Les workers sont les machines qui exécutent les charges de travail (Pods). Ils nécessitent trois composants principaux :
1. **Un Container Runtime :** `containerd`, pour démarrer et isoler les conteneurs (via `runc`).
2. **Le Kubelet :** L'agent Kubernetes qui reçoit les ordres de l'API Server et pilote `containerd`.
3. **Le Kube-Proxy :** Le composant réseau qui gère le routage des Services Kubernetes (via iptables).

## Prérequis
- Le Control Plane doit être opérationnel (Chapitre 07).
- Les certificats (Chapitre 03) et kubeconfigs (Chapitre 04) spécifiques à chaque worker doivent être présents sur les nœuds respectifs.
- Les paramètres d'IP Forwarding doivent être activés au niveau de l'infrastructure (voir les LLDs providers).

## Entrées
- Binaires : `runc`, `crictl`, `containerd`, plugins CNI, `kubelet`, `kube-proxy`.
- Variables d'inventaire (`POD_CIDR` spécifique au nœud, `CLUSTER_DNS`).

## Sorties
- Les nœuds `node-0` et `node-1` enregistrés dans le cluster avec le statut `Ready`.

## Étapes

Ces étapes doivent être exécutées sur chaque worker (`node-0` et `node-1`). Le script `scripts/core/07-workers.sh` automatise ce processus.

### 1. Préparation du système et installation des dépendances

Il faut d'abord installer les paquets OS requis et configurer le kernel pour le routage :

```bash
sudo apt-get update
sudo apt-get -y install socat conntrack ipset

# Activation de l'IP Forwarding au niveau kernel
sudo sysctl -w net.ipv4.ip_forward=1
```

### 2. Téléchargement des binaires

```bash
# Versions
CRICTL_VERSION="v1.29.0"
RUNC_VERSION="v1.1.12"
CNI_VERSION="v1.4.0"
CONTAINERD_VERSION="1.7.13"
KUBERNETES_VERSION="v1.29.2"

# CNI Plugins
wget -q --show-progress --https-only --timestamping \
  "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-amd64-${CNI_VERSION}.tgz"
sudo mkdir -p /opt/cni/bin
sudo tar -xvf cni-plugins-linux-amd64-${CNI_VERSION}.tgz -C /opt/cni/bin/

# containerd, runc, crictl
wget -q --show-progress --https-only --timestamping \
  "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz" \
  "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.amd64" \
  "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz"

sudo tar -xvf containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz -C /
sudo mv runc.amd64 runc
chmod +x runc
sudo mv runc /usr/local/bin/
sudo tar -xvf crictl-${CRICTL_VERSION}-linux-amd64.tar.gz -C /usr/local/bin/

# Kubelet & Kube-proxy
wget -q --show-progress --https-only --timestamping \
  "https://dl.k8s.io/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubelet" \
  "https://dl.k8s.io/release/${KUBERNETES_VERSION}/bin/linux/amd64/kube-proxy"

chmod +x kubelet kube-proxy
sudo mv kubelet kube-proxy /usr/local/bin/
```

### 3. Configuration du réseau CNI (Container Network Interface)

Nous utilisons le plugin `bridge` basique fourni par les plugins CNI standards. Il crée un bridge local (`cni0`) sur le worker et alloue des IPs aux pods à partir du Pod CIDR assigné au nœud.

```bash
# Remplacer par NODE_0_POD_CIDR ou NODE_1_POD_CIDR selon le nœud
POD_CIDR="10.200.0.0/24" 

sudo mkdir -p /etc/cni/net.d
cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "1.0.0",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "1.0.0",
    "name": "lo",
    "type": "loopback"
}
EOF
```

### 4. Configuration de containerd

```bash
sudo mkdir -p /etc/containerd/
cat <<EOF | sudo tee /etc/containerd/config.toml
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      snapshotter = "overlayfs"
      [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime]
        runtime_type = "io.containerd.runc.v2"
        [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime.options]
          SystemdCgroup = true
EOF

cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF
```

### 5. Configuration du Kubelet

```bash
HOSTNAME=$(hostname)
sudo mkdir -p /var/lib/kubelet /var/lib/kubernetes
sudo cp ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/
sudo cp ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
sudo cp ca.pem /var/lib/kubernetes/

cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
EOF

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### 6. Configuration du Kube-proxy

```bash
sudo mkdir -p /var/lib/kube-proxy
sudo cp kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### 7. Démarrage des services

```bash
sudo systemctl daemon-reload
sudo systemctl enable containerd kubelet kube-proxy
sudo systemctl start containerd kubelet kube-proxy
```

## Validations

Retournez sur la `jumpbox` (ou votre poste local configuré) et vérifiez que les nœuds se sont bien enregistrés :

```bash
kubectl get nodes --kubeconfig admin.kubeconfig
```
Les deux nœuds `node-0` et `node-1` doivent apparaître avec le statut `Ready`.

## Points de vigilance
- **SystemdCgroup = true :** Il est impératif que containerd et kubelet utilisent le même gestionnaire de cgroups (`systemd`). Si containerd utilise `cgroupfs` et kubelet `systemd`, le nœud sera instable.
- **Routage asymétrique :** Si les nœuds sont `Ready` mais que les pods ne peuvent pas communiquer entre `node-0` et `node-1`, le problème vient presque toujours du routage de l'infrastructure (Firewall, Source/Dest Check, IP Forwarding), pas de Kubernetes.

## Dépendances
- Control Plane opérationnel.
- Réseau d'infrastructure correctement configuré pour autoriser le trafic du Pod CIDR (`10.200.0.0/16`).

## Articulation avec les autres chapitres
Le cluster est maintenant complet et fonctionnel. Le Chapitre 09 (Smoke Tests) permettra de valider que toutes les fonctionnalités (déploiements, services, logs, chiffrement) opèrent correctement.
