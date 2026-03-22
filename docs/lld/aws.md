# Low Level Design (LLD) Provider : Amazon Web Services (AWS)

**Version :** 1.0.0
**Auteur :** Zidane Djamal, Architecte technique senior

---

## 1. Présentation du Provider

Amazon Web Services (AWS) est le leader mondial du cloud public en termes de parts de marché et de maturité des services. Dans le cadre de ce projet, AWS est utilisé pour démontrer le déploiement de Kubernetes sur une infrastructure EC2 classique, au sein d'un VPC dédié. L'intérêt principal de ce provider réside dans sa large adoption en entreprise : la majorité des architectes et ingénieurs plateforme rencontreront AWS dans leur parcours professionnel.

L'infrastructure sera provisionnée via Terraform en utilisant le provider `aws`. L'ensemble des ressources sera créé dans une seule région et une seule Availability Zone (AZ), conformément au périmètre de la V1.

---

## 2. Hypothèses Spécifiques

- L'utilisateur dispose d'un compte AWS avec les droits IAM suffisants pour créer des ressources VPC, EC2, et Security Groups.
- L'AWS CLI est installée et configurée localement (`aws configure` avec Access Key et Secret Key).
- Le déploiement cible une seule AZ (ex: `eu-west-1a`) pour minimiser les coûts et la complexité.
- Les instances utilisent une AMI Ubuntu 22.04 LTS officielle (Canonical).
- L'accès SSH est géré via une Key Pair EC2 créée par Terraform.
- Le compte AWS dispose des quotas par défaut suffisants pour 4 instances `t3.medium`.

---

## 3. Architecture Réseau

### 3.1. Composants Réseau

| Ressource AWS | Nom | Description |
| :--- | :--- | :--- |
| **VPC** | `k8s-thw-vpc` | VPC dédié avec CIDR `10.240.0.0/16` |
| **Subnet** | `k8s-thw-subnet` | Sous-réseau unique `10.240.0.0/24` dans l'AZ cible |
| **Internet Gateway** | `k8s-thw-igw` | Passerelle Internet attachée au VPC |
| **Route Table** | `k8s-thw-rt` | Table de routage avec route par défaut vers l'IGW |
| **Security Group** | `k8s-thw-sg` | Groupe de sécurité unique pour tous les nœuds |

### 3.2. Plan d'Adressage

| Bloc CIDR | Usage |
| :--- | :--- |
| `10.240.0.0/16` | VPC CIDR |
| `10.240.0.0/24` | Subnet infrastructure (instances EC2) |
| `10.200.0.0/16` | Pod CIDR global |
| `10.200.0.0/24` | Pod CIDR node-0 |
| `10.200.1.0/24` | Pod CIDR node-1 |
| `10.32.0.0/24` | Service CIDR |

### 3.3. Routes pour le Pod CIDR

AWS ne route pas nativement le trafic vers les Pod CIDRs. Il est nécessaire de créer des routes dans la Route Table du VPC ou de désactiver le Source/Destination Check sur les instances workers :

| Route | Destination | Target |
| :--- | :--- | :--- |
| Route Pod node-0 | `10.200.0.0/24` | ENI de `node-0` |
| Route Pod node-1 | `10.200.1.0/24` | ENI de `node-1` |

**Important :** Le paramètre `source_dest_check = false` doit être activé sur chaque instance worker pour permettre le forwarding de paquets dont l'IP source ou destination n'est pas celle de l'instance.

---

## 4. Architecture Compute

### 4.1. Instances

| Hostname | Type d'instance | vCPU | RAM | Disque | IP Privée | IP Publique |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `jumpbox` | `t3.small` | 2 | 2 Go | 20 Go gp3 | `10.240.0.10` | Elastic IP ou auto-assign |
| `server` | `t3.medium` | 2 | 4 Go | 50 Go gp3 | `10.240.0.11` | Elastic IP ou auto-assign |
| `node-0` | `t3.medium` | 2 | 4 Go | 50 Go gp3 | `10.240.0.20` | Auto-assign |
| `node-1` | `t3.medium` | 2 | 4 Go | 50 Go gp3 | `10.240.0.21` | Auto-assign |

### 4.2. Configuration des Instances

Chaque instance sera créée avec les paramètres suivants :

- **AMI :** Ubuntu 22.04 LTS (recherche dynamique via `data "aws_ami"` dans Terraform)
- **Volume type :** `gp3` (General Purpose SSD)
- **Key Pair :** Clé SSH importée ou générée par Terraform
- **Subnet :** `k8s-thw-subnet`
- **Security Group :** `k8s-thw-sg`
- **source_dest_check :** `false` (pour les workers et le server)
- **associate_public_ip_address :** `true` (pour l'accès SSH direct en V1)

---

## 5. Sécurité

### 5.1. Security Group (`k8s-thw-sg`)

**Règles Ingress :**

| Protocole | Port(s) | Source | Description |
| :--- | :--- | :--- | :--- |
| TCP | 22 | `0.0.0.0/0` | Accès SSH |
| TCP | 6443 | `0.0.0.0/0` | API Kubernetes |
| TCP | 2379-2380 | `10.240.0.0/24` | etcd client/peer |
| TCP | 10250 | `10.240.0.0/24` | Kubelet API |
| TCP | 10259 | `10.240.0.0/24` | kube-scheduler |
| TCP | 10257 | `10.240.0.0/24` | kube-controller-manager |
| All | All | `10.240.0.0/24` | Trafic interne cluster |
| All | All | `10.200.0.0/16` | Trafic Pod CIDR |
| ICMP | -1 | `0.0.0.0/0` | Ping |

**Règles Egress :**

| Protocole | Port(s) | Destination | Description |
| :--- | :--- | :--- | :--- |
| All | All | `0.0.0.0/0` | Tout le trafic sortant autorisé |

### 5.2. Principes de Sécurité V1

Pour la V1, la sécurité est volontairement simplifiée. Il n'y a pas de rôles IAM dédiés aux instances (pas d'Instance Profile), pas de VPC Endpoints, et pas de NACLs restrictives (les NACLs par défaut autorisent tout). Le périmètre de sécurité repose sur le Security Group et l'authentification SSH par clé.

---

## 6. Accès SSH

L'accès SSH est configuré via une Key Pair EC2. La `jumpbox` sert de bastion :

1. L'utilisateur se connecte à la `jumpbox` depuis son poste local :
   ```bash
   ssh -i ~/.ssh/k8s-thw.pem ubuntu@<JUMPBOX_PUBLIC_IP>
   ```
2. Depuis la `jumpbox`, l'utilisateur accède aux autres nœuds via SSH par IP privée :
   ```bash
   ssh ubuntu@10.240.0.11  # server
   ssh ubuntu@10.240.0.20  # node-0
   ssh ubuntu@10.240.0.21  # node-1
   ```
3. La clé privée SSH doit être copiée sur la `jumpbox` (via `scp`) ou un agent SSH forwarding doit être utilisé (`ssh -A`).

---

## 7. IP / DNS

### 7.1. Adresses IP

Les IP privées sont assignées statiquement via Terraform (paramètre `private_ip` dans le bloc `aws_instance`). Les IP publiques sont attribuées automatiquement par le subnet (paramètre `map_public_ip_on_launch = true`) ou via des Elastic IPs pour une persistance au redémarrage.

### 7.2. Résolution DNS

AWS fournit un DNS interne au VPC (résolution automatique des hostnames privés). Cependant, pour garantir la cohérence avec les autres providers, le fichier `/etc/hosts` de chaque nœud sera enrichi par un script de préparation avec les correspondances hostname-IP.

---

## 8. Variables Attendues

### 8.1. Variables Terraform (`variables.tf`)

| Variable | Type | Valeur par défaut | Description |
| :--- | :--- | :--- | :--- |
| `aws_region` | `string` | `eu-west-1` | Région AWS |
| `aws_az` | `string` | `eu-west-1a` | Availability Zone |
| `instance_type_server` | `string` | `t3.medium` | Type d'instance pour server |
| `instance_type_worker` | `string` | `t3.medium` | Type d'instance pour workers |
| `instance_type_jumpbox` | `string` | `t3.small` | Type d'instance pour jumpbox |
| `ssh_public_key_path` | `string` | `~/.ssh/id_ed25519.pub` | Chemin vers la clé publique SSH |

---

## 9. Structure Terraform Prévue

```text
terraform/aws/
├── main.tf                  # Provider AWS, backend local
├── variables.tf             # Variables d'entrée
├── outputs.tf               # Sorties (IPs publiques, privées)
├── network.tf               # VPC, Subnet, IGW, Route Table, Security Group
├── compute.tf               # Instances EC2 (jumpbox, server, node-0, node-1)
├── routes.tf                # Routes pour le Pod CIDR
├── inventory.tf             # Génération du fichier inventory.env
├── templates/
│   └── inventory.env.tpl    # Template pour l'inventory
├── terraform.tfvars.example # Exemple de fichier de variables
└── README.md                # Instructions spécifiques AWS
```

---

## 10. Structure Scripts Prévue

```text
scripts/providers/aws/
├── 00-validate-prerequisites.sh   # Vérifie aws cli, terraform, ssh-keygen
├── 01-provision.sh                # Wrapper autour de terraform apply
├── 99-cleanup.sh                  # Wrapper autour de terraform destroy
└── README.md                      # Instructions d'utilisation
```

---

## 11. Exemple d'Inventory

```bash
# === Kubernetes The Hard Way - AWS Inventory ===
# Provider: Amazon Web Services
# Region: eu-west-1 / AZ: eu-west-1a

PROVIDER="aws"
REGION="eu-west-1"
ZONE="eu-west-1a"

JUMPBOX_PUBLIC_IP="54.229.xxx.xxx"
SERVER_PUBLIC_IP="54.229.xxx.xxx"
NODE_0_PUBLIC_IP="54.229.xxx.xxx"
NODE_1_PUBLIC_IP="54.229.xxx.xxx"

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
SSH_KEY_PATH="~/.ssh/k8s-thw"
```

---

## 12. Flux d'Exécution

1. **Pré-requis :** Vérifier l'installation de `aws` CLI, `terraform`, et la configuration des credentials AWS.
2. **Provisionnement :** Se placer dans `terraform/aws/`, copier `terraform.tfvars.example` en `terraform.tfvars`, puis exécuter :
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
3. **Vérification de l'inventory :** Vérifier que `inventories/aws/inventory.env` a été correctement généré.
4. **Connexion à la Jumpbox :** `ssh -i ~/.ssh/k8s-thw ubuntu@<JUMPBOX_PUBLIC_IP>`
5. **Clonage du dépôt sur la Jumpbox :** `git clone https://github.com/zdmooc/kubernetes-the-hard-way-multicloud.git`
6. **Sourcing de l'inventory :** `source inventories/aws/inventory.env`
7. **Exécution séquentielle des scripts Core :** `01-prerequisites.sh` à `11-smoke-tests.sh`
8. **Collecte des preuves :** Les scripts génèrent automatiquement des fichiers dans `evidence/`.

---

## 13. Flux de Cleanup

1. **Nettoyage Kubernetes (optionnel) :** Suppression des ressources Kubernetes de test.
2. **Destruction de l'infrastructure :**
   ```bash
   cd terraform/aws/
   terraform destroy -auto-approve
   ```

**Vérification post-cleanup :** Exécuter `aws ec2 describe-instances --filters "Name=tag:Name,Values=k8s-thw-*" --query "Reservations[].Instances[].InstanceId"` pour confirmer la suppression.

---

## 14. Risques Spécifiques

| Risque | Impact | Probabilité | Mitigation |
| :--- | :--- | :--- | :--- |
| **Coûts EC2 non maîtrisés** | Facturation inattendue | Moyen | Toujours exécuter `terraform destroy` ; configurer AWS Budgets |
| **Elastic IP non libérée** | Facturation résiduelle | Moyen | Vérifier les EIPs après destroy : `aws ec2 describe-addresses` |
| **Source/Dest Check oublié** | Trafic Pod bloqué | Élevé | Automatiser via Terraform (`source_dest_check = false`) |
| **AMI obsolète** | Vulnérabilités de sécurité | Faible | Utiliser un data source Terraform pour récupérer la dernière AMI |

---

## 15. Points d'Attention

- **Facturation :** Les instances `t3.medium` coûtent environ 0,042 USD/heure chacune en `eu-west-1`. Avec 4 instances, le coût horaire est d'environ 0,17 USD. Les Elastic IPs non associées à une instance en cours d'exécution sont facturées.
- **Source/Destination Check :** C'est le point technique le plus critique sur AWS. Sans la désactivation de ce contrôle, le routage des pods entre workers échouera silencieusement.
- **Key Pair :** La clé privée SSH ne doit jamais être versionnée dans le dépôt Git. Elle doit être générée localement et référencée par chemin.
- **Régions :** Le choix de `eu-west-1` est arbitraire. L'utilisateur peut choisir n'importe quelle région disposant des types d'instances requis.

---

## 16. Limites Connues de la V1

- Déploiement mono-AZ (pas de résilience géographique).
- Pas de Load Balancer (ALB/NLB) devant l'API Server.
- Pas de NAT Gateway (les instances ont des IP publiques directes).
- Pas d'Instance Profile IAM (pas d'intégration avec les services AWS depuis les pods).
- Pas de VPC Endpoints (le trafic vers les API AWS passe par Internet).
- Pas d'intégration avec AWS KMS pour le chiffrement des secrets etcd.
- Les routes VPC pour le Pod CIDR ne sont pas scalables au-delà de quelques nœuds.

---
**Signé :**
*Zidane Djamal*
*Architecte technique senior*
