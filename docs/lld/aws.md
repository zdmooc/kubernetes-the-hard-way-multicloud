# docs/lld/aws.md

# Low Level Design (LLD) Provider : Amazon Web Services (AWS)

**Version :** 1.1.0  
**Auteur :** Zidane Djamal  
**Rôle :** Architecte technique senior

---

## 1. Présentation du Provider

Amazon Web Services (AWS) constitue un provider majeur du dépôt `kubernetes-the-hard-way-multicloud`.

Son intérêt dans cette architecture multi-cloud est double :

- représenter le cas d’usage le plus fréquent en entreprise pour du provisionnement IaaS classique ;
- démontrer l’adaptation du socle Kubernetes « hard way » à un environnement EC2/VPC standard.

Dans cette architecture, l’overlay AWS a une responsabilité claire :

- provisionner les ressources IaaS minimales ;
- créer le réseau VPC et les routes nécessaires ;
- créer les instances EC2 supportant le cluster ;
- générer `inventories/aws/inventory.env` lorsque le provider est exécuté avec succès.

Le provider AWS ne déploie pas Kubernetes lui-même. Il prépare l’environnement d’exécution du socle.

---

## 2. Hypothèses Spécifiques

- L’utilisateur dispose d’un compte AWS avec des droits suffisants pour créer des ressources VPC, Subnet, Internet Gateway, Route Table, Security Group, Key Pair et EC2.
- Le CLI `aws` est installé et configuré localement.
- Le déploiement cible une seule région et une seule Availability Zone pour la V1, par défaut `eu-west-1` / `eu-west-1a`.
- Les instances utilisent une AMI Ubuntu 22.04 LTS récupérée dynamiquement via `data "aws_ami"`.
- L’accès SSH repose sur une Key Pair EC2 créée à partir de la clé publique locale fournie à Terraform.
- Le dimensionnement exact dépend du code Terraform réel :
  - `jumpbox` est définie explicitement en `t3.micro` ;
  - `server` utilise `var.instance_type_server` ;
  - `node-0` et `node-1` utilisent `var.instance_type_worker`.
- Le provider AWS est présent structurellement et techniquement exploitable en V1, avec génération d’un `inventory.env` visible dans le code Terraform.

---

## 3. Architecture Réseau

### 3.1. Composants Réseau

| Ressource AWS | Nom | Description |
| :--- | :--- | :--- |
| **VPC** | `k8s-thw-vpc` | VPC dédié avec CIDR `10.240.0.0/24` |
| **Subnet** | `k8s-thw-subnet` | Sous-réseau unique `10.240.0.0/24` dans l’AZ cible |
| **Internet Gateway** | `k8s-thw-igw` | Passerelle Internet attachée au VPC |
| **Route Table** | `k8s-thw-rt` | Table de routage avec route par défaut vers l’IGW |
| **Route Table Association** | `k8s_rta` | Association entre le subnet et la route table |
| **Security Group** | `k8s-thw-sg` | Groupe de sécurité unique appliqué aux nœuds |

### 3.2. Plan d'Adressage

| Bloc CIDR | Usage |
| :--- | :--- |
| `10.240.0.0/24` | CIDR VPC et subnet infrastructure |
| `10.200.0.0/16` | Pod CIDR global |
| `10.200.0.0/24` | Pod CIDR node-0 |
| `10.200.1.0/24` | Pod CIDR node-1 |
| `10.32.0.0/24` | Service CIDR |

### 3.3. Routes pour le Pod CIDR

AWS ne route pas nativement le trafic du Pod CIDR dans cette architecture V1. Des routes explicites sont créées dans la route table du VPC :

| Route | Destination | Target |
| :--- | :--- | :--- |
| `route_node_0` | `10.200.0.0/24` | Interface réseau primaire de `node-0` |
| `route_node_1` | `10.200.1.0/24` | Interface réseau primaire de `node-1` |

### 3.4. Point d’Attention Réseau

Le routage Pod-to-Pod dépend de deux éléments visibles dans l’implémentation AWS :

- les routes VPC vers les Pod CIDRs ;
- `source_dest_check = false` sur les workers.

Sans ces deux éléments, le trafic inter-pods entre nœuds ne fonctionne pas correctement.

---

## 4. Architecture Compute

### 4.1. Instances

| Hostname | Type d'instance | Disque boot | IP Privée | IP Publique |
| :--- | :--- | :--- | :--- | :--- |
| `jumpbox` | `t3.micro` | 20 Go gp3 | `10.240.0.10` | IP publique auto-assignée |
| `server` | `var.instance_type_server` | 50 Go gp3 | `10.240.0.11` | IP publique auto-assignée |
| `node-0` | `var.instance_type_worker` | 50 Go gp3 | `10.240.0.20` | IP publique auto-assignée |
| `node-1` | `var.instance_type_worker` | 50 Go gp3 | `10.240.0.21` | IP publique auto-assignée |

### 4.2. Configuration observée dans le code Terraform

Les éléments visibles dans `terraform/aws/main.tf` sont les suivants :

- AMI Ubuntu 22.04 LTS récupérée dynamiquement via `data "aws_ami"` ;
- `jumpbox` fixée en `t3.micro` ;
- `server` piloté par `var.instance_type_server` ;
- workers pilotés par `var.instance_type_worker` ;
- `private_ip` statiques définies explicitement ;
- `root_block_device` en `gp3` avec tailles cohérentes pour le lab ;
- `key_name` issu de la Key Pair créée par Terraform ;
- `source_dest_check = false` sur les workers ;
- instances créées dans le subnet unique du provider.

### 4.3. Interprétation d’architecture

Cette implémentation confirme une architecture V1 :

- simple à relire ;
- déterministe sur les IP privées ;
- adaptée à un laboratoire mono-AZ ;
- suffisante pour jouer le rôle d’overlay AWS de référence secondaire après GCP.

---

## 5. Sécurité

### 5.1. Security Group (`k8s-thw-sg`)

Le Security Group visible dans `terraform/aws/main.tf` est volontairement simple.

**Règles Ingress visibles :**

| Protocole | Port(s) | Source | Description |
| :--- | :--- | :--- | :--- |
| All | All | `10.240.0.0/24`, `10.200.0.0/16` | Trafic interne cluster et Pod CIDR |
| TCP | `22` | `0.0.0.0/0` | Accès SSH |
| TCP | `6443` | `0.0.0.0/0` | API Kubernetes |
| ICMP | -1 | `0.0.0.0/0` | Ping |

**Règle Egress visible :**

| Protocole | Port(s) | Destination | Description |
| :--- | :--- | :--- | :--- |
| All | All | `0.0.0.0/0` | Tout le trafic sortant autorisé |

### 5.2. Principes de Sécurité V1

Pour la V1, la sécurité reste volontairement simple :

- un Security Group unique ;
- pas d’Instance Profile IAM visible ;
- pas de VPC Endpoint ;
- pas de segmentation réseau avancée ;
- authentification SSH par clé.

### 5.3. Point d’attention documentaire

Le LLD AWS ne doit pas décrire des ouvertures de ports détaillées non visibles dans le code réel. Les flux etcd, kubelet et control plane sont bien nécessaires fonctionnellement, mais le Security Group actuellement implémenté est plus large et plus simple.

---

## 6. Accès SSH

L’accès SSH repose sur une Key Pair EC2 créée à partir de la clé publique locale fournie à Terraform.

### 6.1. Principes

- l’utilisateur fournit une clé publique via `ssh_public_key_path` ;
- Terraform crée une ressource `aws_key_pair` ;
- les instances EC2 utilisent cette Key Pair ;
- l’utilisateur SSH par défaut est `ubuntu`.

### 6.2. Accès opératoire

L’output Terraform fournit une commande de référence vers la jumpbox, construite à partir de :

- `ssh_user` ;
- `ssh_public_key_path` transformé en chemin de clé privée.

La jumpbox reste le point d’entrée privilégié pour les opérations du socle.

### 6.3. Point d’attention

Le dépôt réel s’appuie sur la convention `~/.ssh/id_ed25519.pub` côté clé publique d’entrée. Le LLD AWS ne doit donc pas imposer un chemin de type `~/.ssh/k8s-thw` qui n’est pas visible dans les fichiers réels.

---

## 7. IP / DNS

### 7.1. Adresses IP

Les IP privées sont assignées statiquement via `private_ip` dans les ressources `aws_instance`.

Les IP publiques sont issues du subnet avec `map_public_ip_on_launch = true`, ce qui rend les instances directement joignables en V1 sans NAT Gateway ni bastion privé supplémentaire.

### 7.2. Résolution DNS

AWS fournit un DNS interne de VPC. Le LLD AWS ne doit pas affirmer qu’un enrichissement automatique de `/etc/hosts` existe déjà dans le provider si cela n’est pas visible dans les scripts présents. Cette préparation peut relever d’une étape manuelle ou du socle selon le niveau de maturité du dépôt.

---

## 8. Variables Attendues

### 8.1. Variables Terraform (`variables.tf`)

| Variable | Type | Valeur par défaut | Description |
| :--- | :--- | :--- | :--- |
| `aws_region` | `string` | `eu-west-1` | Région AWS |
| `aws_az` | `string` | `eu-west-1a` | Availability Zone |
| `instance_type_server` | `string` | `t3.medium` | Type d’instance pour `server` |
| `instance_type_worker` | `string` | `t3.medium` | Type d’instance pour les workers |
| `ssh_public_key_path` | `string` | `~/.ssh/id_ed25519.pub` | Chemin vers la clé publique SSH |
| `ssh_user` | `string` | `ubuntu` | Utilisateur SSH |
| `pod_cidr` | `string` | `10.200.0.0/16` | Pod CIDR global |
| `service_cidr` | `string` | `10.32.0.0/24` | Service CIDR |
| `cluster_dns` | `string` | `10.32.0.10` | IP du DNS cluster |

### 8.2. Variables d’inventaire

Le fichier `inventories/aws/inventory.env`, lorsqu’il est généré, porte notamment :

- les IP publiques et privées ;
- les CIDR Kubernetes ;
- les versions de référence ;
- les paramètres d’accès SSH.

### 8.3. `lab.env.example` vs `inventory.env`

Le provider AWS suit la distinction standard du dépôt :

- `inventories/aws/lab.env.example` : exemple versionné ;
- `inventories/aws/inventory.env` : fichier d’exécution généré localement par Terraform quand le provider est exécuté.

---

## 9. Structure Terraform Réelle

```text
terraform/aws/
├── inventory.tpl
├── main.tf
├── outputs.tf
├── variables.tf
└── versions.tf
```

### 9.1. Rôle des fichiers

- `main.tf` : réseau, sécurité, Key Pair, AMI, instances EC2, routes Pod CIDR, génération de l’inventaire ;
- `variables.tf` : variables d’entrée ;
- `outputs.tf` : IP publiques et commande SSH ;
- `versions.tf` : contraintes Terraform et providers ;
- `inventory.tpl` : template utilisé pour générer `inventories/aws/inventory.env`.

### 9.2. Point d’attention documentaire

Le dépôt réel ne montre pas, à ce stade :

- `network.tf` ;
- `compute.tf` ;
- `routes.tf` ;
- `inventory.tf` ;
- `templates/` ;
- `terraform.tfvars.example`.

Le LLD AWS doit donc décrire la structure réellement présente, et non une structure cible théorique.

---

## 10. Structure Scripts Réelle

```text
scripts/aws/
├── cleanup.sh
└── provision.sh
```

### 10.1. Rôle des scripts provider

Les scripts AWS sont des wrappers légers autour de Terraform :

- `provision.sh` : exécute le provisioning depuis `terraform/aws/` ;
- `cleanup.sh` : exécute la destruction Terraform puis supprime `inventories/aws/inventory.env`.

### 10.2. Limite actuelle à expliciter

Le script `provision.sh` référence encore un fichier `terraform.tfvars` et mentionne `terraform.tfvars.example`, alors que ce dernier n’est pas visible dans le dépôt actuel. Cet écart doit être documenté comme une dette de stabilisation V1.

### 10.3. Relation avec le socle

Ces scripts ne déploient pas Kubernetes. Ils préparent uniquement l’infrastructure et le contrat d’interface attendu par le socle (`inventory.env`).

---

## 11. Exemple d'Inventory

```bash
PROVIDER="aws"
REGION="eu-west-1"
ZONE="eu-west-1a"

JUMPBOX_PUBLIC_IP="52.x.x.x"
SERVER_PUBLIC_IP="52.x.x.x"
NODE_0_PUBLIC_IP="52.x.x.x"
NODE_1_PUBLIC_IP="52.x.x.x"

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

Cet exemple reste aligné avec :

- `inventory.tpl` ;
- `inventories/aws/lab.env.example` ;
- la baseline technique V1 du dépôt.

---

## 12. Flux d'Exécution

Le flux de déploiement AWS V1 peut être résumé ainsi :

1. **Préparation locale**
   - vérifier `aws`, `terraform`, la clé SSH et les prérequis système ;
   - vérifier la configuration des credentials AWS.

2. **Provisionnement AWS**
   - exécuter Terraform dans `terraform/aws/` ou utiliser `scripts/aws/provision.sh` ;
   - fournir les variables nécessaires selon le contexte.

3. **Génération de l’inventaire**
   - vérifier la présence de `inventories/aws/inventory.env` ;
   - contrôler son contenu via `scripts/shared/render-inventory.sh` si besoin.

4. **Exécution du socle Kubernetes**
   - suivre les étapes documentées dans `docs/core/` ;
   - utiliser les scripts mutualisés de `scripts/shared/` en appui.

5. **Validation**
   - exécuter les validations décrites dans `docs/core/09-smoke-tests.md` ;
   - utiliser `scripts/shared/smoke-tests.sh` pour la partie actuellement automatisée.

6. **Conservation des preuves**
   - stocker les sorties utiles dans `evidence/` selon la discipline opératoire retenue.

### 12.1. Point d’attention

Le flux AWS ne doit pas être décrit comme une exécution séquentielle d’une suite `01-*` à `11-*` dans `scripts/core/`, car cette structure n’existe pas dans le dépôt réel.

---

## 13. Flux de Cleanup

Le nettoyage AWS repose sur le wrapper réel `scripts/aws/cleanup.sh` ou, à défaut, sur `terraform destroy` exécuté dans `terraform/aws/`.

### 13.1. Séquence visible

Le script réel effectue :

1. un positionnement dans `terraform/aws/` ;
2. une demande de confirmation interactive ;
3. un `terraform destroy -auto-approve` ;
4. une suppression locale de `inventories/aws/inventory.env`.

### 13.2. Vérifications recommandées

Après cleanup, il est recommandé de vérifier :

- l’absence d’instances résiduelles ;
- l’absence d’inventaire local résiduel ;
- la cohérence des ressources réseau supprimées.

### 13.3. Interprétation

Ce cleanup est cohérent avec une V1 de laboratoire : simple, explicite, et centré sur le retour à un état propre après expérimentation.

---

## 14. Risques Spécifiques

| Risque | Impact | Probabilité | Mitigation |
| :--- | :--- | :--- | :--- |
| Coûts EC2 non maîtrisés | Facturation inattendue | Moyen | Toujours exécuter `terraform destroy` ; surveiller les coûts |
| Ressource réseau résiduelle | Facturation ou incohérence | Moyen | Vérifier la suppression des ressources après cleanup |
| Source/Dest Check oublié | Trafic Pod bloqué | Élevé | Vérifier `source_dest_check = false` sur les workers |
| AMI obsolète ou inadaptée | Risque de sécurité ou incompatibilité | Faible à moyen | S’appuyer sur le `data "aws_ami"` et revalider |
| Inventaire incomplet | Blocage du socle | Moyen | Vérifier `inventory.env` avant bootstrap |

---

## 15. Points d’Attention

- Le point technique le plus critique sur AWS reste la combinaison routes VPC + `source_dest_check = false`.
- Les instances sont exposées publiquement en V1 via un subnet public et `map_public_ip_on_launch = true`.
- La clé privée SSH ne doit jamais être versionnée dans le dépôt.
- Le fichier `terraform.tfvars.example` n’est pas encore présent alors qu’il est encore mentionné dans certains wrappers ou documents périphériques.
- Le choix de `eu-west-1` / `eu-west-1a` est un choix de laboratoire et peut être adapté.

---

## 16. Limites Connues de la V1

- déploiement mono-AZ ;
- pas de load balancer devant l’API server ;
- pas de NAT Gateway ;
- pas d’Instance Profile IAM visible ;
- pas de VPC Endpoint ;
- pas d’intégration AWS KMS pour le chiffrement etcd ;
- routage Pod CIDR reposant sur des routes VPC peu scalables.

---

## 17. Conclusion

Le provider AWS joue un rôle important dans la crédibilité multi-cloud du dépôt.

Sa valeur tient à la cohérence déjà visible entre :

- VPC ;
- subnet ;
- sécurité ;
- EC2 ;
- routes Pod CIDR ;
- inventaire ;
- wrappers provider.

Le rôle du LLD AWS est donc double :

- documenter fidèlement l’implémentation actuelle ;
- préparer l’alignement des autres providers cloud au même niveau de lisibilité.

---

## 18. Signature

**Auteur :** Zidane Djamal  
**Rôle :** Architecte technique senior



---
---