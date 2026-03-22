# Low Level Design (LLD) Provider : Google Cloud Platform (GCP)

**Version :** 1.0.0
**Auteur :** Zidane Djamal, Architecte technique senior

---

## 1. Présentation du Provider

Google Cloud Platform (GCP) est le fournisseur Cloud historique utilisé par le projet original *Kubernetes The Hard Way* de Kelsey Hightower. Ce choix n'est pas anodin : Kubernetes est né chez Google, et GCP offre une intégration native avec l'écosystème (GKE, gcloud CLI, réseau VPC performant). Dans le cadre de ce projet multi-cloud, GCP sert de **provider de référence** : c'est l'environnement sur lequel les scripts Core sont validés en premier.

L'infrastructure sera provisionnée via Terraform en utilisant le provider `google`. L'ensemble des ressources sera créé dans un projet GCP dédié, au sein d'une seule région et d'une seule zone de disponibilité (suffisant pour un laboratoire).

---

## 2. Hypothèses Spécifiques

- L'utilisateur dispose d'un compte GCP avec la facturation activée et un projet existant.
- Le SDK `gcloud` est installé et configuré localement (authentification via `gcloud auth application-default login`).
- Le déploiement cible une seule zone (ex: `europe-west1-b`) pour minimiser les coûts.
- Les instances utilisent l'image `ubuntu-2204-lts` (Ubuntu 22.04 LTS) de la famille `ubuntu-os-cloud`.
- Le quota par défaut du projet GCP est suffisant pour 4 instances `e2-standard-2`.
- L'accès SSH est géré via les métadonnées d'instance GCP (injection de clé publique SSH).

---

## 3. Architecture Réseau

### 3.1. Composants Réseau

| Ressource GCP | Nom | Description |
| :--- | :--- | :--- |
| **VPC Network** | `k8s-thw-vpc` | Réseau VPC en mode custom (pas d'auto-subnets) |
| **Subnet** | `k8s-thw-subnet` | Sous-réseau unique `10.240.0.0/24` dans la région cible |
| **Firewall Rule (interne)** | `k8s-thw-allow-internal` | Autorise tout le trafic TCP, UDP, ICMP au sein du subnet `10.240.0.0/24` et du Pod CIDR `10.200.0.0/16` |
| **Firewall Rule (externe)** | `k8s-thw-allow-external` | Autorise SSH (22), HTTPS API (6443), ICMP depuis `0.0.0.0/0` |
| **Static IP** | `k8s-thw-api-ip` | Adresse IP publique statique pour l'accès à l'API Server (optionnel) |

### 3.2. Plan d'Adressage

| Bloc CIDR | Usage |
| :--- | :--- |
| `10.240.0.0/24` | Subnet infrastructure (VMs) |
| `10.200.0.0/16` | Pod CIDR global |
| `10.200.0.0/24` | Pod CIDR node-0 |
| `10.200.1.0/24` | Pod CIDR node-1 |
| `10.32.0.0/24` | Service CIDR |

### 3.3. Routes Statiques

GCP ne route pas nativement le trafic vers les Pod CIDRs. Des routes statiques doivent être créées pour acheminer le trafic des pods entre les workers :

| Route | Destination | Next Hop |
| :--- | :--- | :--- |
| `k8s-thw-route-node-0` | `10.200.0.0/24` | Instance `node-0` |
| `k8s-thw-route-node-1` | `10.200.1.0/24` | Instance `node-1` |

---

## 4. Architecture Compute

### 4.1. Instances

| Hostname | Type d'instance | vCPU | RAM | Disque | IP Privée | IP Publique |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `jumpbox` | `e2-standard-2` | 2 | 8 Go | 20 Go SSD | `10.240.0.10` | Éphémère |
| `server` | `e2-standard-2` | 2 | 8 Go | 200 Go SSD | `10.240.0.11` | Éphémère ou Statique |
| `node-0` | `e2-standard-2` | 2 | 8 Go | 200 Go SSD | `10.240.0.20` | Éphémère |
| `node-1` | `e2-standard-2` | 2 | 8 Go | 200 Go SSD | `10.240.0.21` | Éphémère |

### 4.2. Configuration des Instances

Chaque instance sera créée avec les paramètres suivants :

- **Image :** `ubuntu-2204-jammy-v20240126` (ou dernière version stable de la famille `ubuntu-2204-lts`)
- **Boot disk type :** `pd-ssd`
- **Network tags :** `k8s-thw` (pour l'application des firewall rules)
- **Metadata :** `enable-oslogin=FALSE` (gestion SSH par clé injectée)
- **can_ip_forward :** `true` (obligatoire pour les workers, nécessaire au routage des pods)

---

## 5. Sécurité

### 5.1. Firewall Rules

**Règle interne (`k8s-thw-allow-internal`) :**

| Paramètre | Valeur |
| :--- | :--- |
| Source ranges | `10.240.0.0/24`, `10.200.0.0/16` |
| Protocoles | TCP (tous ports), UDP (tous ports), ICMP |
| Target tags | `k8s-thw` |
| Direction | INGRESS |

**Règle externe (`k8s-thw-allow-external`) :**

| Paramètre | Valeur |
| :--- | :--- |
| Source ranges | `0.0.0.0/0` |
| Protocoles | TCP (22, 6443), ICMP |
| Target tags | `k8s-thw` |
| Direction | INGRESS |

### 5.2. Principes de Sécurité V1

Pour la V1, le périmètre de sécurité est volontairement simplifié. Il n'y a pas de Service Account dédié (utilisation du Service Account par défaut du projet), pas de VPC Service Controls, et pas de Cloud Armor. Le périmètre de sécurité repose uniquement sur les Firewall Rules et l'authentification SSH par clé.

---

## 6. Accès SSH

L'accès SSH est configuré via l'injection de la clé publique dans les métadonnées de chaque instance. La `jumpbox` sert de bastion :

1. L'utilisateur se connecte à la `jumpbox` depuis son poste local : `gcloud compute ssh jumpbox`
2. Depuis la `jumpbox`, l'utilisateur accède aux autres nœuds via SSH par IP privée : `ssh server`, `ssh node-0`, `ssh node-1`
3. La clé SSH privée est générée localement et distribuée sur la `jumpbox` lors du provisionnement.

**Commande de connexion directe :**
```bash
gcloud compute ssh jumpbox --zone=europe-west1-b
```

---

## 7. IP / DNS

### 7.1. Adresses IP

Les IP privées sont assignées statiquement via Terraform (paramètre `network_ip` dans le bloc `network_interface`). Les IP publiques sont éphémères par défaut (attribuées automatiquement par GCP et susceptibles de changer au redémarrage). Une IP publique statique peut être réservée pour le nœud `server` si l'on souhaite un accès stable à l'API Kubernetes depuis l'extérieur.

### 7.2. Résolution DNS

La résolution interne est assurée par le DNS interne de GCP (résolution automatique des hostnames au sein du VPC). Le fichier `/etc/hosts` de chaque nœud sera enrichi par un script de préparation pour garantir la résolution des noms `jumpbox`, `server`, `node-0`, `node-1` vers les IP privées.

---

## 8. Variables Attendues

### 8.1. Variables Terraform (`variables.tf`)

| Variable | Type | Valeur par défaut | Description |
| :--- | :--- | :--- | :--- |
| `project_id` | `string` | — (obligatoire) | ID du projet GCP |
| `region` | `string` | `europe-west1` | Région de déploiement |
| `zone` | `string` | `europe-west1-b` | Zone de déploiement |
| `machine_type` | `string` | `e2-standard-2` | Type d'instance pour tous les nœuds |
| `os_image` | `string` | `ubuntu-os-cloud/ubuntu-2204-lts` | Image OS |
| `ssh_public_key_path` | `string` | `~/.ssh/id_ed25519.pub` | Chemin vers la clé publique SSH |

### 8.2. Variables d'Inventory Générées

Le fichier `inventories/gcp/inventory.env` sera généré automatiquement par Terraform via un template.

---

## 9. Structure Terraform Prévue

```text
terraform/gcp/
├── main.tf                  # Provider Google, backend local
├── variables.tf             # Variables d'entrée
├── outputs.tf               # Sorties (IPs publiques, privées)
├── network.tf               # VPC, Subnet, Firewall Rules, Routes
├── compute.tf               # Instances (jumpbox, server, node-0, node-1)
├── inventory.tf             # Génération du fichier inventory.env
├── templates/
│   └── inventory.env.tpl    # Template pour l'inventory
├── terraform.tfvars.example # Exemple de fichier de variables
└── README.md                # Instructions spécifiques GCP
```

---

## 10. Structure Scripts Prévue

```text
scripts/providers/gcp/
├── 00-validate-prerequisites.sh   # Vérifie gcloud, terraform, ssh-keygen
├── 01-provision.sh                # Wrapper autour de terraform apply
├── 99-cleanup.sh                  # Wrapper autour de terraform destroy
└── README.md                      # Instructions d'utilisation
```

Ces scripts sont des wrappers légers autour de Terraform. Ils ne contiennent pas de logique Kubernetes ; leur rôle est uniquement de simplifier le provisionnement et le nettoyage de l'infrastructure GCP.

---

## 11. Exemple d'Inventory

Voici un exemple complet du fichier `inventories/gcp/inventory.env` tel qu'il serait généré après un `terraform apply` réussi :

```bash
# === Kubernetes The Hard Way - GCP Inventory ===
# Provider: Google Cloud Platform
# Region: europe-west1 / Zone: europe-west1-b

PROVIDER="gcp"
REGION="europe-west1"
ZONE="europe-west1-b"

JUMPBOX_PUBLIC_IP="34.78.12.45"
SERVER_PUBLIC_IP="34.78.12.46"
NODE_0_PUBLIC_IP="34.78.12.47"
NODE_1_PUBLIC_IP="34.78.12.48"

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

---

## 12. Flux d'Exécution

Le flux complet de déploiement sur GCP suit les étapes suivantes :

1. **Pré-requis :** Vérifier l'installation de `gcloud`, `terraform`, et la configuration du projet GCP.
2. **Authentification :** Exécuter `gcloud auth application-default login`.
3. **Provisionnement :** Se placer dans `terraform/gcp/`, copier `terraform.tfvars.example` en `terraform.tfvars`, renseigner le `project_id`, puis exécuter :
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
4. **Vérification de l'inventory :** Vérifier que le fichier `inventories/gcp/inventory.env` a été correctement généré.
5. **Connexion à la Jumpbox :** `gcloud compute ssh jumpbox --zone=europe-west1-b`
6. **Clonage du dépôt sur la Jumpbox :** `git clone https://github.com/zdmooc/kubernetes-the-hard-way-multicloud.git`
7. **Sourcing de l'inventory :** `source inventories/gcp/inventory.env`
8. **Exécution séquentielle des scripts Core :** `01-prerequisites.sh` à `11-smoke-tests.sh`
9. **Collecte des preuves :** Les scripts génèrent automatiquement des fichiers dans `evidence/`.

---

## 13. Flux de Cleanup

Le nettoyage de l'environnement GCP est réalisé en deux étapes :

1. **Nettoyage Kubernetes (optionnel) :** Suppression des ressources Kubernetes déployées (Deployments, Services, Secrets de test).
2. **Destruction de l'infrastructure :**
   ```bash
   cd terraform/gcp/
   terraform destroy -auto-approve
   ```

Cette commande supprime l'intégralité des ressources GCP créées : instances, VPC, subnet, firewall rules, routes statiques, et IP statiques.

**Vérification post-cleanup :** Exécuter `gcloud compute instances list --filter="tags.items=k8s-thw"` pour confirmer qu'aucune instance résiduelle ne subsiste.

---

## 14. Risques Spécifiques

| Risque | Impact | Probabilité | Mitigation |
| :--- | :--- | :--- | :--- |
| **Dépassement de quotas** | Échec du provisionnement | Faible | Vérifier les quotas via `gcloud compute project-info describe` avant le déploiement |
| **Coûts non maîtrisés** | Facturation inattendue | Moyen | Toujours exécuter `terraform destroy` après les tests ; configurer des alertes de budget |
| **Changement d'API GCP** | Incompatibilité Terraform | Faible | Figer la version du provider Terraform Google (`~> 5.0`) |
| **IP publiques éphémères** | Perte d'accès SSH après redémarrage | Moyen | Utiliser `gcloud compute ssh` (qui résout dynamiquement) ou réserver des IP statiques |

---

## 15. Points d'Attention

- **Facturation :** Les instances `e2-standard-2` coûtent environ 0,067 USD/heure chacune. Avec 4 instances, le coût horaire est d'environ 0,27 USD. Il est impératif de détruire l'infrastructure après chaque session de travail.
- **Régions et Zones :** Le choix de la zone `europe-west1-b` est arbitraire. L'utilisateur peut choisir n'importe quelle zone disposant des types d'instances requis.
- **Forwarding IP :** Le paramètre `can_ip_forward = true` est indispensable sur les instances workers pour permettre le routage des paquets du Pod CIDR. Sans ce paramètre, le trafic inter-pods entre workers sera silencieusement rejeté par GCP.
- **Firewall Rules :** La règle `k8s-thw-allow-external` ouvre le port 6443 à `0.0.0.0/0`. En environnement de production, cette règle devrait être restreinte à l'IP source de l'administrateur.

---

## 16. Limites Connues de la V1

- Déploiement mono-zone (pas de résilience géographique).
- Pas de Load Balancer devant l'API Server.
- Pas de Cloud NAT (les instances ont des IP publiques directes).
- Pas de gestion avancée des Service Accounts GCP (utilisation du SA par défaut).
- Pas d'intégration avec Cloud KMS pour le chiffrement des secrets etcd.
- Les routes statiques pour le Pod CIDR ne sont pas scalables au-delà de quelques nœuds (un CNI comme Calico ou Cilium serait nécessaire en V2).
- Pas de Private Google Access pour les API GCP depuis les instances.

---
**Signé :**
*Zidane Djamal*
*Architecte technique senior*
