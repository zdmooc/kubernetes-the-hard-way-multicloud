# Low Level Design (LLD) Provider : IBM Cloud

**Version :** 1.0.0
**Auteur :** Zidane Djamal, Architecte technique senior

---

## 1. Présentation du Provider

IBM Cloud est un fournisseur Cloud qui se distingue par son positionnement sur les charges de travail d'entreprise critiques, son offre OpenShift managée (ROKS), et sa présence forte dans les secteurs réglementés (finance, santé, secteur public). Dans le cadre de ce projet, IBM Cloud est utilisé pour démontrer le déploiement de Kubernetes sur des Virtual Servers au sein d'un VPC de deuxième génération (VPC Gen2).

L'infrastructure sera provisionnée via Terraform en utilisant le provider `ibm`. L'ensemble des ressources sera créé dans un VPC dédié, au sein d'une seule région et d'une seule zone de disponibilité.

---

## 2. Hypothèses Spécifiques

- L'utilisateur dispose d'un compte IBM Cloud avec un abonnement Pay-As-You-Go ou Subscription (les comptes Lite ne permettent pas de créer des VPC).
- L'IBM Cloud CLI (`ibmcloud`) est installée et configurée localement (`ibmcloud login`).
- Le plugin VPC Infrastructure est installé : `ibmcloud plugin install vpc-infrastructure`.
- Le déploiement cible une seule zone (ex: `eu-de-1` dans la région `eu-de` / Francfort).
- Les instances utilisent l'image `ibm-ubuntu-22-04-4-minimal-amd64-1` (Ubuntu 22.04 LTS).
- L'accès SSH est géré via une SSH Key enregistrée dans IBM Cloud.
- Le quota par défaut du compte est suffisant pour 4 instances `bx2-2x8`.

---

## 3. Architecture Réseau

### 3.1. Composants Réseau

| Ressource IBM Cloud | Nom | Description |
| :--- | :--- | :--- |
| **VPC** | `k8s-thw-vpc` | Virtual Private Cloud dédié |
| **Subnet** | `k8s-thw-subnet` | Sous-réseau unique `10.240.0.0/24` dans la zone cible |
| **Public Gateway** | `k8s-thw-pgw` | Passerelle publique pour l'accès Internet sortant |
| **Security Group** | `k8s-thw-sg` | Groupe de sécurité pour les instances |
| **Floating IP** | `k8s-thw-<hostname>-fip` | IP flottante publique par instance |

### 3.2. Plan d'Adressage

| Bloc CIDR | Usage |
| :--- | :--- |
| `10.240.0.0/24` | Subnet infrastructure (Virtual Servers) |
| `10.200.0.0/16` | Pod CIDR global |
| `10.200.0.0/24` | Pod CIDR node-0 |
| `10.200.1.0/24` | Pod CIDR node-1 |
| `10.32.0.0/24` | Service CIDR |

### 3.3. Routes pour le Pod CIDR

IBM Cloud VPC supporte les routes personnalisées (VPC Routing Tables). Des routes doivent être créées pour acheminer le trafic des pods entre les workers :

| Route | Destination | Next Hop |
| :--- | :--- | :--- |
| `route-node-0-pods` | `10.200.0.0/24` | `10.240.0.20` (node-0) |
| `route-node-1-pods` | `10.200.1.0/24` | `10.240.0.21` (node-1) |

**Important :** Le paramètre `allow_ip_spoofing = true` doit être activé sur les interfaces réseau des workers pour permettre le forwarding de paquets avec des IP sources différentes de l'IP de l'interface.

---

## 4. Architecture Compute

### 4.1. Instances

| Hostname | Profil | vCPU | RAM | Disque | IP Privée | IP Publique |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `jumpbox` | `bx2-2x8` | 2 | 8 Go | 100 Go | `10.240.0.10` | Floating IP |
| `server` | `bx2-2x8` | 2 | 8 Go | 100 Go | `10.240.0.11` | Floating IP |
| `node-0` | `bx2-2x8` | 2 | 8 Go | 100 Go | `10.240.0.20` | Floating IP |
| `node-1` | `bx2-2x8` | 2 | 8 Go | 100 Go | `10.240.0.21` | Floating IP |

### 4.2. Configuration des Instances

Chaque instance sera créée avec les paramètres suivants :

- **Image :** `ibm-ubuntu-22-04-4-minimal-amd64-1` (Ubuntu 22.04 LTS minimal)
- **Profile :** `bx2-2x8` (Balanced, 2 vCPU, 8 Go RAM)
- **Boot volume :** 100 Go, `general-purpose` IOPS tier
- **SSH Key :** Référence à la clé SSH enregistrée dans IBM Cloud
- **Primary Network Interface :** IP privée statique, Security Group `k8s-thw-sg`
- **allow_ip_spoofing :** `true` sur les interfaces des workers

---

## 5. Sécurité

### 5.1. Security Group (`k8s-thw-sg`)

**Règles Inbound :**

| Direction | Protocole | Port(s) | Source | Description |
| :--- | :--- | :--- | :--- | :--- |
| Inbound | TCP | 22 | `0.0.0.0/0` | Accès SSH |
| Inbound | TCP | 6443 | `0.0.0.0/0` | API Kubernetes |
| Inbound | ALL | ALL | `10.240.0.0/24` | Trafic interne cluster |
| Inbound | ALL | ALL | `10.200.0.0/16` | Trafic Pod CIDR |
| Inbound | ICMP | Type 8 | `0.0.0.0/0` | Ping (Echo Request) |

**Règles Outbound :**

| Direction | Protocole | Port(s) | Destination | Description |
| :--- | :--- | :--- | :--- | :--- |
| Outbound | ALL | ALL | `0.0.0.0/0` | Tout le trafic sortant autorisé |

### 5.2. Principes de Sécurité V1

Pour la V1, il n'y a pas de Trusted Profile, pas d'intégration avec IBM Key Protect, pas de Context-Based Restrictions, et pas de Flow Logs. Le périmètre de sécurité repose sur le Security Group et l'authentification SSH par clé.

---

## 6. Accès SSH

L'accès SSH est configuré via une SSH Key enregistrée dans IBM Cloud et référencée lors de la création des instances. La `jumpbox` sert de bastion :

1. L'utilisateur se connecte à la `jumpbox` depuis son poste local :
   ```bash
   ssh -i ~/.ssh/id_ed25519 root@<JUMPBOX_FLOATING_IP>
   ```
2. Depuis la `jumpbox`, l'utilisateur accède aux autres nœuds via SSH par IP privée.

**Note IBM Cloud :** Par défaut, l'utilisateur SSH sur les images Ubuntu IBM Cloud est `root` (et non `ubuntu`). Cela peut être modifié via `cloud-init` si nécessaire.

---

## 7. IP / DNS

### 7.1. Adresses IP

Les IP privées sont assignées via le paramètre `primary_ipv4_address` dans le bloc `primary_network_interface` de la ressource Terraform `ibm_is_instance`. Les Floating IPs sont des ressources distinctes attachées aux interfaces réseau des instances.

### 7.2. Résolution DNS

IBM Cloud VPC fournit un résolveur DNS interne. Le fichier `/etc/hosts` de chaque nœud sera enrichi par un script de préparation avec les correspondances hostname-IP.

---

## 8. Variables Attendues

### 8.1. Variables Terraform (`variables.tf`)

| Variable | Type | Valeur par défaut | Description |
| :--- | :--- | :--- | :--- |
| `ibmcloud_api_key` | `string` | — (obligatoire) | Clé API IBM Cloud |
| `region` | `string` | `eu-de` | Région IBM Cloud |
| `zone` | `string` | `eu-de-1` | Zone de disponibilité |
| `profile` | `string` | `bx2-2x8` | Profil d'instance |
| `ssh_key_name` | `string` | — (obligatoire) | Nom de la SSH Key enregistrée dans IBM Cloud |

---

## 9. Structure Terraform Prévue

```text
terraform/ibmcloud/
├── main.tf                  # Provider IBM, configuration
├── variables.tf             # Variables d'entrée
├── outputs.tf               # Sorties (IPs, Floating IPs)
├── network.tf               # VPC, Subnet, Public Gateway, Security Group, Routes
├── compute.tf               # Instances (jumpbox, server, node-0, node-1)
├── floating_ips.tf          # Floating IPs attachées aux instances
├── inventory.tf             # Génération du fichier inventory.env
├── templates/
│   └── inventory.env.tpl    # Template pour l'inventory
├── terraform.tfvars.example # Exemple de fichier de variables
└── README.md                # Instructions spécifiques IBM Cloud
```

---

## 10. Structure Scripts Prévue

```text
scripts/providers/ibmcloud/
├── 00-validate-prerequisites.sh   # Vérifie ibmcloud cli, terraform, ssh-keygen
├── 01-provision.sh                # Wrapper autour de terraform apply
├── 02-register-ssh-key.sh         # Enregistre la clé SSH dans IBM Cloud si nécessaire
├── 99-cleanup.sh                  # Wrapper autour de terraform destroy
└── README.md                      # Instructions d'utilisation
```

---

## 11. Exemple d'Inventory

```bash
# === Kubernetes The Hard Way - IBM Cloud Inventory ===
# Provider: IBM Cloud
# Region: eu-de / Zone: eu-de-1

PROVIDER="ibmcloud"
REGION="eu-de"
ZONE="eu-de-1"

JUMPBOX_PUBLIC_IP="161.156.xxx.xxx"
SERVER_PUBLIC_IP="161.156.xxx.xxx"
NODE_0_PUBLIC_IP="161.156.xxx.xxx"
NODE_1_PUBLIC_IP="161.156.xxx.xxx"

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

SSH_USER="root"
SSH_KEY_PATH="~/.ssh/id_ed25519"
```

---

## 12. Flux d'Exécution

1. **Pré-requis :** Vérifier l'installation de `ibmcloud` CLI, `terraform`, et l'authentification IBM Cloud.
2. **Enregistrement de la clé SSH :** Si ce n'est pas déjà fait, enregistrer la clé publique SSH dans IBM Cloud :
   ```bash
   ibmcloud is key-create k8s-thw-key @~/.ssh/id_ed25519.pub
   ```
3. **Provisionnement :** Se placer dans `terraform/ibmcloud/`, copier `terraform.tfvars.example` en `terraform.tfvars`, renseigner l'API key et le nom de la SSH key, puis exécuter :
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
4. **Vérification de l'inventory :** Vérifier que `inventories/ibmcloud/inventory.env` a été correctement généré.
5. **Connexion à la Jumpbox :** `ssh -i ~/.ssh/id_ed25519 root@<JUMPBOX_FLOATING_IP>`
6. **Clonage du dépôt sur la Jumpbox :** `git clone https://github.com/zdmooc/kubernetes-the-hard-way-multicloud.git`
7. **Sourcing de l'inventory :** `source inventories/ibmcloud/inventory.env`
8. **Exécution séquentielle des scripts Core :** `01-prerequisites.sh` à `11-smoke-tests.sh`
9. **Collecte des preuves :** Les scripts génèrent automatiquement des fichiers dans `evidence/`.

---

## 13. Flux de Cleanup

1. **Nettoyage Kubernetes (optionnel) :** Suppression des ressources Kubernetes de test.
2. **Destruction de l'infrastructure :**
   ```bash
   cd terraform/ibmcloud/
   terraform destroy -auto-approve
   ```

**Vérification post-cleanup :** Exécuter `ibmcloud is instances --output json | jq '.[] | select(.name | startswith("k8s-thw"))'` pour confirmer la suppression.

---

## 14. Risques Spécifiques

| Risque | Impact | Probabilité | Mitigation |
| :--- | :--- | :--- | :--- |
| **Coûts Floating IPs** | Facturation résiduelle | Moyen | Les Floating IPs non attachées sont facturées ; vérifier après destroy |
| **IP Spoofing désactivé** | Trafic Pod bloqué | Élevé | Automatiser via Terraform (`allow_ip_spoofing = true`) |
| **Compte Lite insuffisant** | Impossible de créer un VPC | Élevé | Migrer vers un compte Pay-As-You-Go |
| **Provider Terraform IBM moins mature** | Bugs ou limitations | Moyen | Figer la version du provider et tester régulièrement |

---

## 15. Points d'Attention

- **Facturation :** Les instances `bx2-2x8` coûtent environ 0,096 USD/heure chacune. Les Floating IPs sont facturées séparément (environ 0,005 USD/heure chacune).
- **IP Spoofing :** C'est le point technique le plus critique sur IBM Cloud. Le paramètre `allow_ip_spoofing` doit être activé sur les interfaces réseau des workers. Sans ce paramètre, le trafic inter-pods sera rejeté par le VPC.
- **SSH User :** L'utilisateur SSH par défaut sur les images Ubuntu IBM Cloud est `root`, contrairement aux autres providers où c'est `ubuntu`. Les scripts Core doivent gérer cette différence via la variable `SSH_USER` de l'inventory.
- **API Key :** La clé API IBM Cloud est sensible et ne doit jamais être versionnée. Utiliser une variable d'environnement `IC_API_KEY` ou un fichier `terraform.tfvars` non versionné.

---

## 16. Limites Connues de la V1

- Déploiement mono-zone (pas de résilience géographique).
- Pas de Load Balancer IBM Cloud devant l'API Server.
- Pas d'intégration avec IBM Key Protect pour le chiffrement des secrets etcd.
- Pas de Trusted Profile pour les instances.
- Pas de Flow Logs pour l'audit réseau.
- Les routes VPC pour le Pod CIDR ne sont pas scalables au-delà de quelques nœuds.
- Le provider Terraform IBM est moins mature que les providers GCP, AWS ou Azure.

---
**Signé :**
*Zidane Djamal*
*Architecte technique senior*
