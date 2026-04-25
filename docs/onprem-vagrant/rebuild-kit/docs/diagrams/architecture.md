# Diagrammes Mermaid

## Topologie

```mermaid
flowchart TB
  PC[PC Windows Git Bash] --> VB[VirtualBox Host-Only Network 192.168.56.0/24]
  VB --> J[jumpbox 192.168.56.10]
  VB --> C0[controller-0 192.168.56.11]
  VB --> C1[controller-1 192.168.56.12]
  VB --> C2[controller-2 192.168.56.13]
  VB --> W0[worker-0 192.168.56.21 PodCIDR 10.200.0.0/24]
  VB --> W1[worker-1 192.168.56.22 PodCIDR 10.200.1.0/24]

  J --> C0
  J --> C1
  J --> C2
  J --> W0
  J --> W1

  W0 -. route 10.200.1.0/24 via 192.168.56.22 .-> W1
  W1 -. route 10.200.0.0/24 via 192.168.56.21 .-> W0
```

## Séquence de construction

```mermaid
sequenceDiagram
  participant PC as PC Windows
  participant J as jumpbox
  participant C as controllers
  participant W as workers
  participant API as kube-apiserver
  participant ETCD as etcd

  PC->>PC: vagrant destroy -f / vagrant up
  PC->>J: upload SSH keys
  J->>C: prepare hosts
  J->>W: prepare hosts
  J->>J: generate PKI + kubeconfigs
  J->>C: distribute certs/configs
  J->>W: distribute certs/configs
  J->>C: bootstrap etcd
  C->>ETCD: etcd HA ready
  J->>C: bootstrap API server
  API->>ETCD: persist cluster state
  J->>C: bootstrap controller-manager + scheduler
  J->>API: create RBAC bindings
  J->>W: bootstrap kubelet + kube-proxy
  W->>API: register nodes
  J->>API: approve kubelet CSRs
  J->>W: add PodCIDR routes
  J->>API: deploy CoreDNS
  J->>API: deploy nginx + busybox
  J->>API: smoke tests
```

## Flux DNS final

```mermaid
flowchart LR
  BB[busybox 10.200.0.52 worker-0] --> DNS_SVC[kube-dns Service 10.32.0.10]
  DNS_SVC --> CD1[CoreDNS 10.200.1.52 worker-1]
  DNS_SVC --> CD2[CoreDNS 10.200.1.55 worker-1]
  BB --> NGINX_SVC[nginx Service 10.32.0.102]
  NGINX_SVC --> NGINX[nginx Pod 10.200.0.53 worker-0]
```
