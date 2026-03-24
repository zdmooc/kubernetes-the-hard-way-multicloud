# docs/lld/ibmcloud.md

# Low Level Design (LLD) Provider : IBM Cloud

**Version :** 1.1.0  
**Auteur :** Zidane Djamal  
**Rôle :** Architecte technique senior

---

## 1. Présentation du Provider

IBM Cloud constitue un provider important du dépôt `kubernetes-the-hard-way-multicloud`.

Son intérêt dans cette architecture multi-cloud est double :

- représenter un cas d’usage orienté charges d’entreprise et VPC Gen2 ;
- démontrer l’adaptation du socle Kubernetes « hard way » à un environnement IBM Cloud basé sur VPC, Virtual Server Instances, Floating IPs et routes VPC.

Dans cette architecture, l’overlay IBM Cloud a une responsabilité claire :

- provisionner les ressources IaaS minimales ;
- créer le réseau, les routes et les interfaces nécessaires ;
- créer les instances supportant le cluster ;
- générer `inventories/ibmcloud/inventory.env` lorsque le provider est exécuté avec succès.

Le provider IBM Cloud ne déploie pas Kubernetes lui-même. Il prépare l’environnement d’exécution du socle.

---

## 2. Hypothèses Spécifiques

- L’utilisateur dispose d’un compte IBM Cloud permettant la création de ressources VPC Gen2.
- Le CLI `ibmcloud` est installé et authentifié localement.
- Le plugin VPC Infrastructure est disponible côté opérateur lorsque nécessaire.
- Le déploiement cible une seule région et une seule zone pour la V1, par défaut `eu-de` / `eu-de-1`.
- Les instances utilisent l’image `ibm-ubuntu-22-04-4-minimal-amd64-1`.
- L’accès SSH repose sur une clé SSH déjà enregistrée dans IBM Cloud et référencée par son nom via `ssh_key_name`.
- Le dimensionnement exact dépend du code Terraform réel :
  - `jumpbox` est définie explicitement en `cx2-2x4` ;
  - `server`, `node-0` et `node-1` utilisent `var.profile` avec une valeur par défaut `bx2-2x8`.
- Le provider IBM Cloud est présent structurellement et techniquement exploitable en V1, avec génération d’un `inventory.env` visible dans le code Terraform.

---

## 3. Architecture Réseau

### 3.1. Composants Réseau

| Ressource IBM Cloud | Nom | Description |
| :--- | :--- | :--- |
| **VPC** | `k8s-thw-vpc` | Virtual Private Cloud dédié |
| **Subnet** | `k8s-thw-subnet` | Sous-réseau unique `10.240.0.0/24` dans la zone cible |
| **Public Gateway** | `k8s-thw-pgw` | Passerelle publique pour l’accès sortant |
| **Security Group** | `k8s-thw-sg` | Groupe de sécurité des instances |
| **Floating IP** | `k8s-thw-<hostname>-fip` | IP publique flottante par instance |
| **VPC Custom Route** | `route-node-0` / `route-node-1` | Routes statiques pour les Pod CIDRs |

### 3.2. Plan d'Adressage

| Bloc CIDR | Usage |
| :--- | :--- |
| `10.240.0.0/24` | Réseau infrastructure (subnet) |
| `10.200.0.0/16` | Pod CIDR global |
| `10.200.0.0/24` | Pod CIDR node-0 |
| `10.200.1.0/24` | Pod CIDR node-1 |
| `10.32.0.0/24` | Service CIDR |

### 3.3. Routes pour le Pod CIDR

IBM Cloud VPC permet la création de routes personnalisées dans la routing table du VPC :

| Route | Destination | Next Hop |
| :--- | :--- | :--- |
| `route-node-0` | `10.200.0.0/24` | `10.240.0.20` |
| `route-node-1` | `10.200.1.0/24` | `10.240.0.21` |

### 3.4. Point d’Attention Réseau

Le routage Pod-to-Pod dépend de deux éléments visibles dans l’implémentation IBM Cloud :

- `allow_ip_spoofing = true` sur les interfaces réseau des workers ;
- les routes VPC pointant vers les IP privées des workers.

Sans ces deux mécanismes, le trafic inter-pods entre nœuds ne fonctionne pas correctement.

---

## 4. Architecture Compute

### 4.1. Instances

| Hostname | Profil | Disque | IP Privée | IP Publique |
| :--- | :--- | :--- | :--- | :--- |
| `jumpbox` | `cx2-2x4` | profil par défaut de l’instance | `10.240.0.10` | Floating IP |
| `server` | `var.profile` | profil par défaut de l’instance | `10.240.0.11` | Floating IP |
| `node-0` | `var.profile` | profil par défaut de l’instance | `10.240.0.20` | Floating IP |
| `node-1` | `var.profile` | profil par défaut de l’instance | `10.240.0.21` | Floating IP |

### 4.2. Configuration observée dans le code Terraform

Les éléments visibles dans `terraform/ibmcloud/main.tf` sont les suivants :

- image `ibm-ubuntu-22-04-4-minimal-amd64-1` récupérée par data source ;
- `jumpbox` fixée à `cx2-2x4` ;
- `server`, `node-0`, `node-1` pilotés par `var.profile` ;
- clés SSH injectées via référence à `data.ibm_is_ssh_key` ;
- IP privées statiques définies dans `primary_ip` ;
- Floating IPs attachées explicitement aux interfaces primaires ;
- `allow_ip_spoofing = true` sur les workers.

### 4.3. Interprétation d’architecture

Cette implémentation confirme une architecture V1 :

- simple à relire ;
- explicite sur les ressources IBM Cloud ;
- cohérente avec un laboratoire mono-zone ;
- suffisamment structurée pour jouer le rôle d’overlay IBM Cloud du dépôt.

---

## 5. Sécurité

### 5.1. Security Group (`k8s-thw-sg`)

Le Security Group visible dans `terraform/ibmcloud/main.tf` est volontairement simple.

**Règles Inbound visibles :**

| Direction | Protocole | Port(s) | Source | Description |
| :--- | :--- | :--- | :--- | :--- |
| Inbound | TCP | `22` | `0.0.0.0/0` | Accès SSH |
| Inbound | TCP | `6443` | `0.0.0.0/0` | API Kubernetes |
| Inbound | ALL | ALL | `10.240.0.0/24` | Trafic interne cluster |
| Inbound | ALL | ALL | `10.200.0.0/16` | Trafic Pod CIDR |
| Inbound | ICMP | type 8 | `0.0.0.0/0` | Ping |

**Règle Outbound visible :**

| Direction | Protocole | Port(s) | Destination | Description |
| :--- | :--- | :--- | :--- | :--- |
| Outbound | ALL | ALL | `0.0.0.0/0` | Tout le trafic sortant autorisé |

### 5.2. Principes de Sécurité V1

Pour la V1, la sécurité reste volontairement simple :

- un Security Group unique ;
- pas de Trusted Profile visible ;
- pas d’intégration Key Protect visible ;
- pas de mécanisme réseau avancé additionnel ;
- authentification SSH par clé.

### 5.3. Point d’attention documentaire

Le LLD IBM Cloud doit décrire le Security Group réellement visible dans `main.tf`, sans extrapoler vers une cible plus détaillée non implémentée.

---

## 6. Accès SSH

L’accès SSH repose sur une clé déjà enregistrée dans IBM Cloud et référencée via `ssh_key_name`.

### 6.1. Principes

- Terraform lit la clé via `data "ibm_is_ssh_key"` ;
- les instances utilisent cette clé au provisionnement ;
- l’utilisateur SSH par défaut est `root` selon `variables.tf` et les inventaires visibles ;
- la jumpbox reste le point d’entrée privilégié pour les opérations du socle.

### 6.2. Accès opératoire

`outputs.tf` fournit une commande SSH de référence vers la jumpbox, construite à partir de :

- `ssh_user` ;
- `ssh_public_key_path` transformé en chemin de clé privée ;
- la Floating IP de la jumpbox.

### 6.3. Point d’attention

Le dépôt réel ne montre pas de script séparé de type `02-register-ssh-key.sh`. Le LLD ne doit donc pas présenter cette étape comme un composant outillé du dépôt, même si l’enregistrement de la clé peut être nécessaire côté opérateur.

---

## 7. IP / DNS

### 7.1. Adresses IP

Les IP privées sont portées par l’interface réseau primaire des instances.

Les IP publiques sont des Floating IPs, ressources distinctes explicitement attachées aux interfaces réseau des instances.

### 7.2. Résolution DNS

IBM Cloud VPC fournit un résolveur DNS interne. Le LLD IBM Cloud ne doit pas affirmer qu’un enrichissement automatique de `/etc/hosts` existe déjà dans le provider si cela n’est pas visible dans les scripts présents. Cette préparation peut relever d’une étape manuelle ou du socle selon le niveau de maturité du dépôt.

---

## 8. Variables Attendues

### 8.1. Variables Terraform (`variables.tf`)

| Variable | Type | Valeur par défaut | Description |
| :--- | :--- | :--- | :--- |
| `ibmcloud_api_key` | `string` | — | Clé API IBM Cloud |
| `region` | `string` | `eu-de` | Région IBM Cloud |
| `zone` | `string` | `eu-de-1` | Zone IBM Cloud |
| `profile` | `string` | `bx2-2x8` | Profil de calcul pour `server` et workers |
| `ssh_key_name` | `string` | — | Nom de la clé SSH enregistrée |
| `ssh_user` | `string` | `root` | Utilisateur SSH |
| `ssh_public_key_path` | `string` | `~/.ssh/id_ed25519.pub` | Chemin local vers la clé publique SSH |
| `pod_cidr` | `string` | `10.200.0.0/16` | Pod CIDR global |
| `service_cidr` | `string` | `10.32.0.0/24` | Service CIDR |
| `cluster_dns` | `string` | `10.32.0.10` | IP du DNS cluster |

### 8.2. Variables d’inventaire

Le fichier `inventories/ibmcloud/inventory.env`, lorsqu’il est généré, porte notamment :

- les IP publiques et privées ;
- les CIDR Kubernetes ;
- les versions de référence ;
- les paramètres d’accès SSH.

### 8.3. `lab.env.example` vs `inventory.env`

Le provider IBM Cloud suit la distinction standard du dépôt :

- `inventories/ibmcloud/lab.env.example` : exemple versionné ;
- `inventories/ibmcloud/inventory.env` : fichier d’exécution généré localement par Terraform quand le provider est exécuté.

---

## 9. Structure Terraform Réelle

```text
terraform/ibmcloud/
├── inventory.tpl
├── main.tf
├── outputs.tf
├── variables.tf
└── versions.tf
```

### 9.1. Rôle des fichiers

- `main.tf` : VPC, subnet, public gateway, security group, image, clé SSH, instances, floating IPs, routes et génération de l’inventaire ;
- `variables.tf` : variables d’entrée ;
- `outputs.tf` : IP publiques et commande SSH ;
- `versions.tf` : contraintes Terraform et providers ;
- `inventory.tpl` : template utilisé pour générer `inventories/ibmcloud/inventory.env`.

### 9.2. Point d’attention documentaire

Le dépôt réel ne montre pas, à ce stade :

- `network.tf` ;
- `compute.tf` ;
- `floating_ips.tf` ;
- `inventory.tf` ;
- `templates/` ;
- `terraform.tfvars.example`.

Le LLD IBM Cloud doit donc décrire la structure réellement présente, et non une structure cible théorique.

---

## 10. Structure Scripts Réelle

```text
scripts/ibmcloud/
├── cleanup.sh
└── provision.sh
```

### 10.1. Rôle des scripts provider

Les scripts IBM Cloud sont des wrappers légers autour de Terraform :

- `provision.sh` : exécute le provisioning depuis `terraform/ibmcloud/` ;
- `cleanup.sh` : exécute la destruction Terraform puis supprime `inventories/ibmcloud/inventory.env`.

### 10.2. Limite actuelle à expliciter

Le script `provision.sh` référence encore un fichier `terraform.tfvars` et mentionne `terraform.tfvars.example`, alors que ce dernier n’est pas visible dans le dépôt actuel. Cet écart doit être documenté comme une dette de stabilisation V1.

### 10.3. Point d’attention

Le dépôt réel ne montre pas de script séparé de type `02-register-ssh-key.sh`. Cette opération peut exister côté opérateur, mais elle ne doit pas être présentée comme une capacité scriptée du dépôt.

---

## 11. Exemple d'Inventory

```bash
PROVIDER="ibmcloud"
REGION="eu-de"
ZONE="eu-de-1"

JUMPBOX_PUBLIC_IP="169.x.x.x"
SERVER_PUBLIC_IP="169.x.x.x"
NODE_0_PUBLIC_IP="169.x.x.x"
NODE_1_PUBLIC_IP="169.x.x.x"

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

Cet exemple reste aligné avec :

- `inventory.tpl` ;
- `inventories/ibmcloud/lab.env.example` ;
- la baseline technique V1 du dépôt.

---

## 12. Flux d'Exécution

Le flux de déploiement IBM Cloud V1 peut être résumé ainsi :

1. **Préparation locale**
   - vérifier `ibmcloud`, `terraform`, la clé SSH et les prérequis système ;
   - vérifier l’authentification IBM Cloud et la disponibilité de la clé SSH référencée.

2. **Provisionnement IBM Cloud**
   - exécuter Terraform dans `terraform/ibmcloud/` ou utiliser `scripts/ibmcloud/provision.sh` ;
   - fournir les variables nécessaires, notamment `ibmcloud_api_key` et `ssh_key_name`.

3. **Génération de l’inventaire**
   - vérifier la présence de `inventories/ibmcloud/inventory.env` ;
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

Le flux IBM Cloud ne doit pas être décrit comme une exécution séquentielle d’une suite `01-*` à `11-*` dans `scripts/core/`, car cette structure n’existe pas dans le dépôt réel.

---

## 13. Flux de Cleanup

Le nettoyage IBM Cloud repose sur le wrapper réel `scripts/ibmcloud/cleanup.sh` ou, à défaut, sur `terraform destroy` exécuté dans `terraform/ibmcloud/`.

### 13.1. Séquence visible

Le script réel effectue :

1. un positionnement dans `terraform/ibmcloud/` ;
2. une demande de confirmation interactive ;
3. un `terraform destroy -auto-approve` ;
4. une suppression locale de `inventories/ibmcloud/inventory.env`.

### 13.2. Vérifications recommandées

Après cleanup, il est recommandé de vérifier :

- l’absence d’instances résiduelles ;
- l’absence de floating IP résiduelle ;
- l’absence d’inventaire local résiduel.

### 13.3. Interprétation

Ce cleanup est cohérent avec une V1 de laboratoire : simple, explicite, et centré sur le retour à un état propre après expérimentation.

---

## 14. Risques Spécifiques

| Risque | Impact | Probabilité | Mitigation |
| :--- | :--- | :--- | :--- |
| Coûts Floating IPs | Facturation résiduelle | Moyen | Vérifier la suppression complète après destroy |
| IP Spoofing désactivé | Trafic Pod bloqué | Élevé | Vérifier `allow_ip_spoofing = true` sur les workers |
| Compte insuffisant | Échec du provisionnement | Élevé | Utiliser un compte compatible VPC Gen2 |
| Provider Terraform IBM moins mature | Bugs ou limitations | Moyen | Figer la version du provider et revalider régulièrement |
| Inventaire incomplet | Blocage du socle | Moyen | Vérifier `inventory.env` avant bootstrap |

---

## 15. Points d'Attention

- **Facturation :** Le coût dépend notamment d’une `jumpbox` en `cx2-2x4`, de trois instances pilotées par `profile` (par défaut `bx2-2x8`) et des Floating IPs. Il est important de détruire l’infrastructure après les tests.
- **IP Spoofing :** C’est le point technique le plus critique sur IBM Cloud. Le paramètre `allow_ip_spoofing` doit être activé sur les interfaces réseau des workers.
- **SSH User :** L’utilisateur SSH courant de la V1 est `root`, contrairement aux autres providers où `ubuntu` est plus fréquent.
- **API Key :** La clé API IBM Cloud est sensible et ne doit jamais être versionnée.

---

## 16. Limites Connues de la V1

- déploiement mono-zone ;
- pas de load balancer IBM Cloud devant l’API server ;
- pas d’intégration avec IBM Key Protect pour le chiffrement etcd ;
- pas de Trusted Profile visible ;
- pas de Flow Logs ;
- routes VPC peu scalables au-delà de quelques nœuds ;
- provider Terraform IBM moins mature que les providers GCP, AWS ou Azure.

---

## 17. Conclusion

Le provider IBM Cloud apporte une valeur forte au dépôt multi-cloud, car il rend visible une implémentation spécifique basée sur :

- VPC Gen2 ;
- Public Gateway ;
- Floating IPs ;
- data source SSH key ;
- `allow_ip_spoofing` ;
- routes VPC personnalisées.

Le rôle du LLD IBM Cloud est donc double :

- documenter fidèlement cette implémentation réelle ;
- compléter le panorama multi-cloud avec une déclinaison distincte de GCP, AWS et Azure.

---

## 18. Signature

**Auteur :** Zidane Djamal  
**Rôle :** Architecte technique senior



---
---