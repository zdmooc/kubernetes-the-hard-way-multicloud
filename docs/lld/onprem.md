# Low Level Design (LLD) Provider : On-Premises

**Version :** 1.0.0
**Auteur :** Zidane Djamal, Architecte technique senior

---

## 1. Présentation du Provider

L'environnement On-Premises (on-prem) représente le déploiement de Kubernetes sur une infrastructure locale, sans dépendance à un fournisseur Cloud public. Ce scénario est pertinent pour les organisations soumises à des contraintes réglementaires strictes (souveraineté des données), pour les environnements déconnectés (air-gapped), ou simplement pour les architectes souhaitant expérimenter sur leur propre matériel.

Dans le cadre de ce projet, l'environnement on-prem est simulé via des machines virtuelles locales créées avec un hyperviseur de type 2 (VirtualBox, libvirt/KVM) ou un hyperviseur de type 1 (Proxmox, VMware ESXi). Le provisionnement peut être réalisé via Terraform (avec le provider `libvirt` pour KVM) ou via des scripts shell utilisant directement les outils de l'hyperviseur.

---

## 2. Hypothèses Spécifiques

- L'utilisateur dispose d'un poste de travail ou d'un serveur avec au moins 16 Go de RAM et 4 cœurs CPU pour héberger 4 VMs simultanément.
- Un hyperviseur est installé et fonctionnel : libvirt/KVM (Linux), VirtualBox (multi-plateforme), ou Proxmox (serveur dédié).
- L'image ISO Ubuntu 22.04 LTS Server est disponible localement ou une image cloud-init compatible est utilisée.
- Le réseau local permet la communication entre les VMs (bridge réseau ou réseau NAT avec port forwarding).
- L'utilisateur a un accès root ou sudo sur la machine hôte.
- Aucun accès Internet n'est requis depuis les VMs pendant le déploiement si les binaires sont pré-téléchargés (scénario air-gapped possible).

---

## 3. Architecture Réseau

### 3.1. Composants Réseau

| Composant | Nom | Description |
| :--- | :--- | :--- |
| **Bridge réseau** | `k8s-thw-br0` | Bridge virtuel connectant toutes les VMs |
| **Réseau virtuel** | `k8s-thw-net` | Réseau libvirt/VirtualBox `10.240.0.0/24` |
| **DHCP** | Désactivé | Les IPs sont assignées statiquement via cloud-init ou configuration manuelle |
| **NAT** | Optionnel | NAT pour l'accès Internet sortant depuis les VMs |

### 3.2. Plan d'Adressage

| Bloc CIDR | Usage |
| :--- | :--- |
| `10.240.0.0/24` | Réseau des VMs |
| `10.240.0.1` | Passerelle (hôte / bridge) |
| `10.200.0.0/16` | Pod CIDR global |
| `10.200.0.0/24` | Pod CIDR node-0 |
| `10.200.1.0/24` | Pod CIDR node-1 |
| `10.32.0.0/24` | Service CIDR |

### 3.3. Routes pour le Pod CIDR

En environnement on-prem, le routage des pods entre workers est géré directement au niveau du système d'exploitation des nœuds. Des routes statiques sont ajoutées sur chaque worker :

**Sur node-0 :**
```bash
sudo ip route add 10.200.1.0/24 via 10.240.0.21
```

**Sur node-1 :**
```bash
sudo ip route add 10.200.0.0/24 via 10.240.0.20
```

Ces routes sont également ajoutées sur le nœud `server` pour permettre au control plane de joindre les pods.

---

## 4. Architecture Compute

### 4.1. Instances

| Hostname | vCPU | RAM | Disque | IP Privée | Accès externe |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `jumpbox` | 1 | 1 Go | 10 Go | `10.240.0.10` | SSH depuis l'hôte |
| `server` | 2 | 4 Go | 40 Go | `10.240.0.11` | SSH via jumpbox |
| `node-0` | 2 | 4 Go | 40 Go | `10.240.0.20` | SSH via jumpbox |
| `node-1` | 2 | 4 Go | 40 Go | `10.240.0.21` | SSH via jumpbox |

**Total requis :** 7 vCPU, 13 Go RAM, 130 Go disque.

### 4.2. Configuration des VMs

Chaque VM sera créée avec les paramètres suivants :

- **OS :** Ubuntu 22.04 LTS Server (installation minimale)
- **Disque :** Format qcow2 (KVM) ou VDI (VirtualBox)
- **Réseau :** Interface unique sur le bridge `k8s-thw-br0`
- **Cloud-init :** Utilisé pour l'injection de la clé SSH, la configuration réseau statique, et le hostname
- **IP forwarding :** Activé au niveau kernel (`net.ipv4.ip_forward=1`) sur tous les nœuds

---

## 5. Sécurité

### 5.1. Filtrage Réseau

En environnement on-prem, il n'y a pas de Security Groups managés. La sécurité réseau repose sur :

- **iptables / nftables :** Règles de filtrage sur chaque nœud (optionnel en V1, le réseau étant isolé).
- **Isolation du bridge :** Le bridge virtuel est isolé du réseau physique de l'hôte (sauf si un bridge externe est utilisé).
- **Pas de pare-feu restrictif en V1 :** Le réseau entre les VMs est considéré comme de confiance (environnement de laboratoire).

### 5.2. Principes de Sécurité V1

Pour la V1, la sécurité repose uniquement sur l'isolation du réseau virtuel et l'authentification SSH par clé. Il n'y a pas de SELinux/AppArmor configuré, pas de firewall restrictif, et pas de chiffrement du disque.

---

## 6. Accès SSH

L'accès SSH est configuré via cloud-init (injection de la clé publique) ou manuellement lors de l'installation de l'OS.

**Depuis l'hôte :**
```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@10.240.0.10  # jumpbox
```

**Depuis la jumpbox :**
```bash
ssh ubuntu@10.240.0.11  # server
ssh ubuntu@10.240.0.20  # node-0
ssh ubuntu@10.240.0.21  # node-1
```

**Note :** En environnement on-prem, la `jumpbox` n'est pas strictement nécessaire comme bastion (l'hôte peut accéder directement à toutes les VMs). Elle est conservée pour maintenir la cohérence architecturale avec les déploiements Cloud.

---

## 7. IP / DNS

### 7.1. Adresses IP

Les IP sont assignées statiquement via cloud-init (fichier `network-config`) ou via la configuration Netplan de chaque VM. Il n'y a pas d'IP publique ; l'accès se fait directement via les IP privées du réseau virtuel.

### 7.2. Résolution DNS

Le fichier `/etc/hosts` de chaque nœud est configuré manuellement ou via cloud-init :

```
10.240.0.10  jumpbox
10.240.0.11  server
10.240.0.20  node-0
10.240.0.21  node-1
```

---

## 8. Variables Attendues

### 8.1. Variables Terraform (`variables.tf`) — Scénario libvirt

| Variable | Type | Valeur par défaut | Description |
| :--- | :--- | :--- | :--- |
| `libvirt_uri` | `string` | `qemu:///system` | URI de connexion libvirt |
| `base_image_path` | `string` | — (obligatoire) | Chemin vers l'image cloud Ubuntu 22.04 |
| `network_name` | `string` | `k8s-thw-net` | Nom du réseau libvirt |
| `ssh_public_key_path` | `string` | `~/.ssh/id_ed25519.pub` | Chemin vers la clé publique SSH |

### 8.2. Variables pour le Scénario Manuel (VirtualBox)

En l'absence de Terraform, les variables sont définies dans un fichier de configuration shell :

```bash
# config.sh
VM_BRIDGE="k8s-thw-br0"
VM_CPUS_JUMPBOX=1
VM_RAM_JUMPBOX=1024
VM_CPUS_SERVER=2
VM_RAM_SERVER=4096
VM_CPUS_WORKER=2
VM_RAM_WORKER=4096
VM_DISK_SIZE=40960  # Mo
ISO_PATH="/path/to/ubuntu-22.04-live-server-amd64.iso"
SSH_PUBLIC_KEY_PATH="~/.ssh/id_ed25519.pub"
```

---

## 9. Structure Terraform Prévue

### 9.1. Scénario libvirt/KVM (Terraform)

```text
terraform/onprem/
├── main.tf                  # Provider libvirt
├── variables.tf             # Variables d'entrée
├── outputs.tf               # Sorties (IPs)
├── network.tf               # Réseau libvirt, bridge
├── compute.tf               # Domaines libvirt (VMs)
├── cloud_init.tf            # Templates cloud-init
├── templates/
│   ├── cloud_init.cfg.tpl   # Template cloud-init user-data
│   ├── network_config.tpl   # Template cloud-init network-config
│   └── inventory.env.tpl    # Template pour l'inventory
├── inventory.tf             # Génération du fichier inventory.env
├── terraform.tfvars.example # Exemple de fichier de variables
└── README.md                # Instructions spécifiques on-prem
```

### 9.2. Scénario VirtualBox (Scripts)

Pour les utilisateurs n'utilisant pas libvirt, des scripts shell alternatifs sont fournis :

```text
scripts/providers/onprem/
├── 00-validate-prerequisites.sh   # Vérifie VBoxManage ou virsh
├── 01-create-network.sh           # Crée le réseau virtuel
├── 02-create-vms.sh               # Crée les 4 VMs
├── 03-configure-network.sh        # Configure les IPs statiques
├── 99-cleanup.sh                  # Supprime les VMs et le réseau
└── README.md                      # Instructions d'utilisation
```

---

## 10. Structure Scripts Prévue

```text
scripts/providers/onprem/
├── 00-validate-prerequisites.sh   # Vérifie les pré-requis (hyperviseur, RAM, CPU)
├── 01-provision.sh                # Wrapper Terraform ou création manuelle des VMs
├── 02-configure-network.sh        # Configuration réseau statique si non cloud-init
├── 99-cleanup.sh                  # Suppression des VMs et du réseau
└── README.md                      # Instructions d'utilisation
```

---

## 11. Exemple d'Inventory

```bash
# === Kubernetes The Hard Way - On-Prem Inventory ===
# Provider: On-Premises (libvirt/KVM)
# Host: workstation.local

PROVIDER="onprem"
REGION="local"
ZONE="local"

# Pas d'IP publiques en on-prem
JUMPBOX_PUBLIC_IP="10.240.0.10"
SERVER_PUBLIC_IP="10.240.0.11"
NODE_0_PUBLIC_IP="10.240.0.20"
NODE_1_PUBLIC_IP="10.240.0.21"

JUMPBOX_PRIVATE_IP="10.240.0.10"
SERVER_PRIVATE_IP="10.240.0.11"
NODE_0_PRIVATE_IP="10.240.0.20"
NODE_1_PRIVATE_IP="10.240.0.21"

POD_CIDR="10.200.0.0/16"
NODE_0_POD_CIDR="10.200.0.0/24"
NODE_1_POD_CIDR="10.200.1.0/24"
SERVICE_CIDR="10.32.0.0/24"
CLUSTER_DNS="10.32.0.10"

KUBERNETES_VERSION="1.29.2"
ETCD_VERSION="3.5.12"
CONTAINERD_VERSION="1.7.13"
CNI_VERSION="1.4.0"
RUNC_VERSION="1.1.12"

SSH_USER="ubuntu"
SSH_KEY_PATH="~/.ssh/id_ed25519"
```

**Note :** En on-prem, les variables `*_PUBLIC_IP` et `*_PRIVATE_IP` ont la même valeur car il n'y a pas de distinction entre IP publique et privée.

---

## 12. Flux d'Exécution

1. **Pré-requis :** Vérifier la disponibilité de l'hyperviseur, les ressources système (RAM, CPU, disque), et la présence de l'image Ubuntu.
2. **Provisionnement :**
   - **Scénario Terraform/libvirt :** Se placer dans `terraform/onprem/`, configurer les variables, puis exécuter `terraform apply`.
   - **Scénario VirtualBox :** Exécuter les scripts `01-create-network.sh` puis `02-create-vms.sh`.
3. **Vérification de l'inventory :** Vérifier que `inventories/onprem/inventory.env` a été correctement généré.
4. **Connexion à la Jumpbox :** `ssh -i ~/.ssh/id_ed25519 ubuntu@10.240.0.10`
5. **Clonage du dépôt sur la Jumpbox :** `git clone https://github.com/zdmooc/kubernetes-the-hard-way-multicloud.git`
6. **Sourcing de l'inventory :** `source inventories/onprem/inventory.env`
7. **Exécution séquentielle des scripts Core :** `01-prerequisites.sh` à `11-smoke-tests.sh`
8. **Collecte des preuves :** Les scripts génèrent automatiquement des fichiers dans `evidence/`.

---

## 13. Flux de Cleanup

1. **Nettoyage Kubernetes (optionnel) :** Suppression des ressources Kubernetes de test.
2. **Destruction de l'infrastructure :**
   - **Scénario Terraform/libvirt :**
     ```bash
     cd terraform/onprem/
     terraform destroy -auto-approve
     ```
   - **Scénario VirtualBox :**
     ```bash
     scripts/providers/onprem/99-cleanup.sh
     ```

**Vérification post-cleanup :** Exécuter `virsh list --all` (libvirt) ou `VBoxManage list vms` (VirtualBox) pour confirmer la suppression.

---

## 14. Risques Spécifiques

| Risque | Impact | Probabilité | Mitigation |
| :--- | :--- | :--- | :--- |
| **Ressources insuffisantes** | VMs lentes ou crash | Moyen | Vérifier les pré-requis (16 Go RAM, 4 CPU) avant le déploiement |
| **Conflit réseau** | Collision d'adresses IP | Faible | Utiliser un CIDR dédié (`10.240.0.0/24`) non utilisé sur le réseau local |
| **Hyperviseur incompatible** | Échec du provisionnement | Faible | Tester avec libvirt/KVM (recommandé) ou VirtualBox |
| **Accès Internet limité** | Impossible de télécharger les binaires | Moyen | Pré-télécharger les binaires sur l'hôte et les copier sur la jumpbox |

---

## 15. Points d'Attention

- **Performances :** Les VMs locales partagent les ressources de l'hôte. Les performances seront inférieures à un déploiement Cloud. Il est recommandé de fermer les applications gourmandes en ressources pendant les tests.
- **IP Forwarding :** Le paramètre kernel `net.ipv4.ip_forward=1` doit être activé sur tous les nœuds. Vérifier avec `sysctl net.ipv4.ip_forward`.
- **Bridge réseau :** La configuration du bridge varie selon l'hyperviseur et la distribution Linux de l'hôte. Consulter la documentation de l'hyperviseur en cas de problème de connectivité.
- **Persistance :** Les VMs libvirt/VirtualBox persistent au redémarrage de l'hôte (si configurées en autostart). Les IPs statiques sont conservées.
- **Scénario Air-Gapped :** Ce provider est le seul à supporter nativement un déploiement sans accès Internet, à condition de pré-télécharger tous les binaires Kubernetes, etcd, containerd, runc, et les plugins CNI.

---

## 16. Limites Connues de la V1

- Pas de haute disponibilité (mono-nœud control plane).
- Pas de stockage partagé entre les workers (pas de NFS, pas de Ceph).
- Pas de Load Balancer (accès direct à l'API Server via l'IP du nœud `server`).
- Performances limitées par les ressources de l'hôte.
- La configuration réseau (bridge) peut varier significativement selon l'hyperviseur et l'OS de l'hôte.
- Pas de gestion centralisée des logs ou du monitoring.
- Le scénario VirtualBox est moins automatisé que le scénario libvirt/Terraform.

---
**Signé :**
*Zidane Djamal*
*Architecte technique senior*
