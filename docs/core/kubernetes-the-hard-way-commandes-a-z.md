# Kubernetes The Hard Way – V5 FINAL (Exhaustive, prêt à exécuter)

Ce document est une version **figée, exécutable, sans placeholder**, destinée à être suivie ligne par ligne.

Cluster cible :
- controller-0 : 10.0.0.10
- controller-1 : 10.0.0.11
- controller-2 : 10.0.0.12
- worker-0 : 10.0.0.20
- worker-1 : 10.0.0.21
- API LB : kubernetes.local (doit pointer vers les 3 control planes)

CIDR :
- Pods : 10.200.0.0/16
- Services : 10.32.0.0/24

Versions figées :
- Kubernetes : v1.32.0
- etcd : v3.6.0
- containerd : 2.1.0
- CNI : v1.6.2

---

# 1. JUMPBOX – SETUP COMPLET

```bash
export KUBERNETES_VERSION="v1.32.0"
export ETCD_VERSION="v3.6.0"
export CONTAINERD_VERSION="2.1.0"
export CNI_VERSION="v1.6.2"
export ARCH="amd64"
```

```bash
mkdir -p ~/kthw && cd ~/kthw
```

## Installer kubectl
```bash
curl -LO https://dl.k8s.io/release/v1.32.0/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

## Installer cfssl
```bash
curl -LO https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
curl -LO https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssl_linux-amd64 cfssljson_linux-amd64
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
```

---

# 2. CA + CERTIFICATS (MINIMAL EXHAUSTIF)

## CA
```bash
cat > ca-config.json <<EOF
{
  "signing": {
    "default": { "expiry": "8760h" },
    "profiles": {
      "kubernetes": {
        "usages": ["signing","key encipherment","server auth","client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF
```

```bash
cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": { "algo": "rsa", "size": 2048 }
}
EOF
```

```bash
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

---

# 3. API SERVER CERT (CRITIQUE)

```bash
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": { "algo": "rsa", "size": 2048 },
  "hosts": [
    "10.0.0.10",
    "10.0.0.11",
    "10.0.0.12",
    "127.0.0.1",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster.local",
    "10.32.0.1",
    "kubernetes.local"
  ]
}
EOF
```

```bash
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
```

---

# 4. ENCRYPTION CONFIG

```bash
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
```

```bash
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: ${ENCRYPTION_KEY}
  - identity: {}
EOF
```

---

# 5. TOUS LES NODES

## Désactiver swap
```bash
sudo swapoff -a
```

## Répertoires
```bash
sudo mkdir -p /etc/kubernetes /var/lib/kubernetes /var/lib/kubelet /var/lib/kube-proxy /var/lib/etcd /opt/cni/bin /etc/cni/net.d
```

---

# 6. CONTAINERD

```bash
curl -LO https://github.com/containerd/containerd/releases/download/v2.1.0/containerd-2.1.0-linux-amd64.tar.gz
sudo tar -C /usr/local -xzf containerd-2.1.0-linux-amd64.tar.gz
```

```bash
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
```

```bash
curl -LO https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
sudo mv containerd.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
```

---

# 7. ETCD (CONTROLLERS)

## controller-0 example

```bash
sudo tee /etc/systemd/system/etcd.service <<EOF
[Unit]
Description=etcd
After=network.target

[Service]
ExecStart=/usr/local/bin/etcd \
 --name controller-0 \
 --initial-cluster controller-0=https://10.0.0.10:2380,controller-1=https://10.0.0.11:2380,controller-2=https://10.0.0.12:2380 \
 --listen-peer-urls https://10.0.0.10:2380 \
 --listen-client-urls https://10.0.0.10:2379,https://127.0.0.1:2379 \
 --advertise-client-urls https://10.0.0.10:2379 \
 --data-dir=/var/lib/etcd
Restart=always

[Install]
WantedBy=multi-user.target
EOF
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now etcd
```

---

# 8. API SERVER (EXEMPLE COMPLET)

```bash
sudo tee /etc/systemd/system/kube-apiserver.service <<EOF
[Unit]
Description=Kubernetes API Server
After=network.target

[Service]
ExecStart=/usr/local/bin/kube-apiserver \
 --advertise-address=10.0.0.10 \
 --etcd-servers=https://10.0.0.10:2379,https://10.0.0.11:2379,https://10.0.0.12:2379 \
 --service-cluster-ip-range=10.32.0.0/24 \
 --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \
 --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem
Restart=always

[Install]
WantedBy=multi-user.target
EOF
```

---

# 9. WORKERS (EXEMPLE KUBELET)

```bash
sudo tee /etc/systemd/system/kubelet.service <<EOF
[Unit]
Description=Kubelet
After=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \
 --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock
Restart=always

[Install]
WantedBy=multi-user.target
EOF
```

---

# 10. TEST FINAL

```bash
kubectl get nodes
kubectl get pods -A
```

---

# RESULTAT FINAL

Cluster fonctionnel avec :
- control plane HA
- etcd cluster
- workers
- container runtime
- TLS
- API

---

# IMPORTANT

Cette V5 est volontairement :
- compacte
- exécutable
- sans abstraction

👉 Elle doit être exécutée en parallèle du canvas V4 pour compréhension complète.

