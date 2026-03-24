# docs/lld/gcp.md

# Low Level Design (LLD) Provider : Google Cloud Platform (GCP)

**Version :** 1.1.0  
**Auteur :** Zidane Djamal  
**Rôle :** Architecte technique senior

---

## 1. Présentation du Provider

Google Cloud Platform (GCP) est le provider de référence de la V1 du dépôt `kubernetes-the-hard-way-multicloud`.

Ce positionnement est cohérent pour trois raisons :

- GCP est le provider historique du lab original *Kubernetes The Hard Way* ;
- l’implémentation Terraform GCP est actuellement la plus concrète dans le dépôt ;
- le provider GCP sert de point d’appui pour stabiliser le contrat d’interface entre infrastructure, inventaire et socle Kubernetes.

Dans cette architecture, l’overlay GCP a une responsabilité claire :

- provisionner les ressources IaaS minimales ;
- préparer le réseau et les routes nécessaires ;
- créer les instances supportant le cluster ;
- générer `inventories/gcp/inventory.env` lorsque le provider est exécuté avec succès.

Le provider GCP ne déploie pas Kubernetes lui-même. Il prépare l’environnement d’exécution du socle.

---

## 2. Hypothèses Spécifiques

- L’utilisateur dispose d’un compte GCP avec facturation activée et d’un projet existant.
- Le CLI `gcloud` est installé et authentifié.
- Le déploiement cible une seule région et une seule zone pour la V1, par défaut `europe-west1` / `europe-west1-b`.
- Les instances utilisent l’image Ubuntu 22.04 LTS visible dans le code Terraform : `ubuntu-os-cloud/ubuntu-2204-lts`.
- Le provider GCP est le provider de référence car son implémentation est aujourd’hui la plus aboutie.
- Le dimensionnement exact dépend du code Terraform réel :
  - `jumpbox` est définie explicitement en `e2-micro` ;
  - `server`, `node-0` et `node-1` utilisent `var.machine_type` avec une valeur par défaut `e2-standard-2`.
- L’accès SSH repose sur l’injection d’une clé publique dans les métadonnées d’instance.

---

## 3. Architecture Réseau

### 3.1. Composants Réseau

| Ressource GCP | Nom | Description |
| :--- | :--- | :--- |
| **VPC Network** | `k8s-thw-vpc` | Réseau VPC custom sans auto-subnets |
| **Subnet** | `k8s-thw-subnet` | Sous-réseau unique `10.240.0.0/24` dans la région cible |
| **Firewall Rule (interne)** | `k8s-thw-allow-internal` | Autorise TCP, UDP et ICMP entre le subnet infrastructure et le Pod CIDR |
| **Firewall Rule (externe)** | `k8s-thw-allow-external` | Autorise `22/TCP`, `6443/TCP` et ICMP depuis `0.0.0.0/0` |
| **Static IP** | `k8s-thw-jumpbox-ip` | Adresse IP publique statique réservée pour la jumpbox |
| **Static IP** | `k8s-thw-server-ip` | Adresse IP publique statique réservée pour le nœud `server` |
| **Static IP** | `k8s-thw-node-0-ip` | Adresse IP publique statique réservée pour `node-0` |
| **Static IP** | `k8s-thw-node-1-ip` | Adresse IP publique statique réservée pour `node-1` |

### 3.2. Plan d’Adressage

| Bloc CIDR | Usage |
| :--- | :--- |
| `10.240.0.0/24` | Réseau infrastructure (VMs) |
| `10.200.0.0/16` | Pod CIDR global |
| `10.200.0.0/24` | Pod CIDR de `node-0` |
| `10.200.1.0/24` | Pod CIDR de `node-1` |
| `10.32.0.0/24` | Service CIDR |

### 3.3. Routes Statiques

Dans cette architecture V1, GCP ne route pas nativement le trafic du Pod CIDR entre workers. Des routes statiques sont donc créées explicitement :

| Route | Destination | Next Hop |
| :--- | :--- | :--- |
| `k8s-thw-route-node-0` | `10.200.0.0/24` | `10.240.0.20` |
| `k8s-thw-route-node-1` | `10.200.1.0/24` | `10.240.0.21` |

### 3.4. Point d’Attention Réseau

Le routage inter-pods repose sur deux éléments visibles dans l’implémentation :

- les routes statiques VPC ;
- `can_ip_forward = true` sur les workers.

Sans ces deux mécanismes, la communication inter-pods entre nœuds ne fonctionne pas correctement.

---

## 4. Architecture Compute

### 4.1. Instances

| Hostname | Type d’instance | Disque boot | IP Privée | IP Publique |
| :--- | :--- | :--- | :--- | :--- |
| `jumpbox` | `e2-micro` | 20 Go | `10.240.0.10` | Statique réservée |
| `server` | `var.machine_type` | 50 Go | `10.240.0.11` | Statique réservée |
| `node-0` | `var.machine_type` | 50 Go | `10.240.0.20` | Statique réservée |
| `node-1` | `var.machine_type` | 50 Go | `10.240.0.21` | Statique réservée |

### 4.2. Configuration Observée dans le Code Terraform

Les éléments visibles dans `terraform/gcp/main.tf` sont les suivants :

- image : `ubuntu-os-cloud/ubuntu-2204-lts` ;
- `jumpbox` avec type fixé à `e2-micro` ;
- `server`, `node-0`, `node-1` avec type piloté par `var.machine_type` ;
- tags réseau : `k8s-thw` + rôle logique (`jumpbox`, `controller`, `worker`) ;
- IP privées statiques définies explicitement ;
- IP publiques associées à des adresses réservées ;
- `can_ip_forward = true` sur les workers ;
- métadonnées SSH injectées via `ssh-keys` ;
- métadonnée `pod-cidr` présente sur les workers.

### 4.3. Interprétation d’Architecture

Cette modélisation confirme que le provider GCP V1 vise :

- une topologie simple à 4 nœuds ;
- une lisibilité pédagogique forte ;
- une stabilité d’adressage ;
- un support explicite du routage Pod CIDR ;
- un provisionnement suffisamment déterministe pour servir de provider de référence.

---

## 5. Sécurité

### 5.1. Firewall Rules

**Règle interne (`k8s-thw-allow-internal`) :**

| Paramètre | Valeur |
| :--- | :--- |
| Source ranges | `10.240.0.0/24`, `10.200.0.0/16` |
| Protocoles | TCP (tous ports), UDP (tous ports), ICMP |
| Direction | INGRESS |

**Règle externe (`k8s-thw-allow-external`) :**

| Paramètre | Valeur |
| :--- | :--- |
| Source ranges | `0.0.0.0/0` |
| Protocoles | TCP (`22`, `6443`), ICMP |
| Direction | INGRESS |

### 5.2. Principes de Sécurité V1

Pour la V1, le périmètre de sécurité reste volontairement simple :

- firewall rules réseau ;
- authentification SSH par clé ;
- isolation logique par VPC et subnet ;
- pas de mécanisme avancé de sécurité cloud de type Cloud Armor, VPC Service Controls ou KMS intégré à ce stade.

### 5.3. Limite de Lecture

Le LLD GCP doit décrire ce qui est visible et cohérent dans le dépôt. Il ne doit pas prétendre à un design sécurité cloud de niveau production tant que celui-ci n’est pas implémenté.

---

## 6. Accès SSH

L’accès SSH est géré par injection de la clé publique via les métadonnées d’instance GCP.

### 6.1. Principes

- l’utilisateur fournit une clé publique via `ssh_public_key_path` ;
- Terraform injecte cette clé dans les métadonnées de chaque instance ;
- le nom d’utilisateur SSH est porté par `ssh_user` (par défaut `ubuntu`) ;
- la jumpbox joue le rôle de point d’entrée privilégié pour les opérations du socle.

### 6.2. Accès Opératoire

Deux modes d’accès sont cohérents avec la V1 :

1. accès à la jumpbox depuis le poste opérateur ;
2. accès aux autres nœuds depuis la jumpbox ou depuis un poste autorisé.

Le dépôt montre également dans `outputs.tf` une commande SSH de référence vers la jumpbox.

### 6.3. Point d’Attention

Le LLD GCP ne doit pas affirmer des mécanismes non visibles dans le dépôt, par exemple une distribution automatique de la clé privée sur la jumpbox. Le point confirmé est l’injection de la clé publique dans les métadonnées des instances.

---

## 7. IP / DNS

### 7.1. Adresses IP

Les IP privées sont assignées statiquement dans les blocs `network_interface`.

Les IP publiques, dans l’implémentation actuelle visible, ne sont pas de simples IP éphémères par défaut : elles sont rattachées à des ressources `google_compute_address` réservées pour :

- `jumpbox` ;
- `server` ;
- `node-0` ;
- `node-1`.

Cela rend l’adressage public plus stable pour les besoins du laboratoire.

### 7.2. Résolution DNS

La résolution interne repose d’abord sur le réseau GCP et sur la cohérence entre hostnames logiques et adresses privées.

Le LLD GCP ne doit pas affirmer qu’un enrichissement automatique de `/etc/hosts` existe déjà côté provider si cela n’est pas visible dans les scripts présents. Cette préparation peut relever du socle ou d’une étape manuelle guidée selon le niveau de maturité du dépôt.

---

## 8. Variables Attendues

### 8.1. Variables Terraform (`variables.tf`)

| Variable | Type | Valeur par défaut | Description |
| :--- | :--- | :--- | :--- |
| `project_id` | `string` | — | ID du projet GCP |
| `region` | `string` | `europe-west1` | Région de déploiement |
| `zone` | `string` | `europe-west1-b` | Zone de déploiement |
| `machine_type` | `string` | `e2-standard-2` | Type des nœuds `server` et workers |
| `ssh_public_key_path` | `string` | `~/.ssh/id_ed25519.pub` | Chemin vers la clé publique SSH |
| `ssh_user` | `string` | `ubuntu` | Utilisateur SSH |
| `pod_cidr` | `string` | `10.200.0.0/16` | Pod CIDR global |
| `service_cidr` | `string` | `10.32.0.0/24` | Service CIDR |
| `cluster_dns` | `string` | `10.32.0.10` | IP du DNS cluster |

### 8.2. Variables d’Inventaire

Le fichier `inventories/gcp/inventory.env`, lorsqu’il est généré, porte notamment :

- les IP publiques et privées ;
- les CIDR Kubernetes ;
- les versions de référence ;
- les paramètres d’accès SSH.

### 8.3. `lab.env.example` vs `inventory.env`

Le provider GCP suit la distinction standard du dépôt :

- `inventories/gcp/lab.env.example` : exemple versionné ;
- `inventories/gcp/inventory.env` : fichier d’exécution généré localement par Terraform quand le provider est exécuté.

---

## 9. Structure Terraform Réelle

```text
terraform/gcp/
├── inventory.tpl
├── main.tf
├── outputs.tf
├── variables.tf
└── versions.tf
```

### 9.1. Rôle des Fichiers

- `main.tf` : provider Google, réseau, firewall rules, IP réservées, instances, routes, génération de l’inventaire ;
- `variables.tf` : variables d’entrée ;
- `outputs.tf` : sorties utiles, notamment IP publiques et commande SSH ;
- `versions.tf` : contraintes Terraform et providers ;
- `inventory.tpl` : template utilisé pour générer `inventories/gcp/inventory.env`.

### 9.2. Point d’Attention Documentaire

Le dépôt réel ne montre pas, à ce stade :

- `network.tf` ;
- `compute.tf` ;
- `inventory.tf` ;
- `templates/` ;
- `terraform.tfvars.example`.

Le LLD GCP doit donc décrire la structure réellement présente, et non une structure cible théorique.

---

## 10. Structure Scripts Réelle

```text
scripts/gcp/
├── cleanup.sh
└── provision.sh
```

### 10.1. Rôle des Scripts Provider

Les scripts GCP sont des wrappers légers autour de Terraform :

- `provision.sh` : exécute le provisioning depuis `terraform/gcp/` ;
- `cleanup.sh` : exécute la destruction Terraform puis supprime `inventories/gcp/inventory.env`.

### 10.2. Limite Actuelle à Expliciter

Le script `provision.sh` référence encore un fichier `terraform.tfvars` et mentionne `terraform.tfvars.example`, alors que ce dernier n’est pas visible dans le dépôt actuel. Cet écart doit être documenté comme une dette de stabilisation V1.

### 10.3. Relation avec le Socle

Ces scripts ne déploient pas Kubernetes. Ils préparent uniquement l’infrastructure et le contrat d’interface attendu par le socle (`inventory.env`).

---

## 11. Exemple d’Inventory

Voici un exemple cohérent du fichier `inventories/gcp/inventory.env` tel qu’il peut être généré après un `terraform apply` réussi :

```bash
PROVIDER="gcp"
REGION="europe-west1"
ZONE="europe-west1-b"

JUMPBOX_PUBLIC_IP="34.x.x.x"
SERVER_PUBLIC_IP="34.x.x.x"
NODE_0_PUBLIC_IP="34.x.x.x"
NODE_1_PUBLIC_IP="34.x.x.x"

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
- `inventories/gcp/lab.env.example` ;
- la baseline technique V1 du dépôt.

---

## 12. Flux d’Exécution

Le flux de déploiement GCP V1 peut être résumé ainsi :

1. **Préparation locale**
   - vérifier `gcloud`, `terraform`, la clé SSH et les prérequis système ;
   - authentifier GCP si nécessaire.

2. **Provisionnement GCP**
   - exécuter Terraform dans `terraform/gcp/` ou utiliser `scripts/gcp/provision.sh` ;
   - fournir les variables nécessaires, en particulier `project_id`.

3. **Génération de l’inventaire**
   - vérifier la présence de `inventories/gcp/inventory.env` ;
   - contrôler son contenu via `scripts/shared/render-inventory.sh` si besoin.

4. **Exécution du socle Kubernetes**
   - suivre les étapes documentées dans `docs/core/` ;
   - utiliser les scripts mutualisés de `scripts/shared/` en appui.

5. **Validation**
   - exécuter les validations décrites dans `docs/core/09-smoke-tests.md` ;
   - utiliser `scripts/shared/smoke-tests.sh` pour la partie actuellement automatisée.

6. **Conservation des preuves**
   - stocker les sorties utiles dans `evidence/` selon la discipline opératoire retenue.

### 12.1. Point d’Attention

Le flux GCP ne doit pas être décrit comme une exécution séquentielle d’une suite `01-*` à `11-*` dans `scripts/core/`, car cette structure n’existe pas dans le dépôt réel.

---

## 13. Flux de Cleanup

Le nettoyage GCP repose sur le wrapper réel `scripts/gcp/cleanup.sh` ou, à défaut, sur `terraform destroy` exécuté dans `terraform/gcp/`.

### 13.1. Séquence Visible

Le script réel effectue :

1. un positionnement dans `terraform/gcp/` ;
2. une demande de confirmation interactive ;
3. un `terraform destroy -auto-approve` ;
4. une suppression locale de `inventories/gcp/inventory.env`.

### 13.2. Vérifications Recommandées

Après cleanup, il est recommandé de vérifier :

- l’absence d’instances résiduelles ;
- l’absence d’adresses IP encore réservées ;
- la suppression effective du fichier `inventories/gcp/inventory.env`.

### 13.3. Interprétation

Ce cleanup est cohérent avec une V1 de laboratoire : simple, explicite et centré sur le retour à un état propre après expérimentation.

---

## 14. Risques Spécifiques

| Risque | Impact | Probabilité | Mitigation |
| :--- | :--- | :--- | :--- |
| Dépassement de quotas | Échec du provisionnement | Faible à moyen | Vérifier les quotas GCP avant déploiement |
| Coûts non maîtrisés | Facturation inattendue | Moyen | Détruire l’infrastructure après les tests |
| Changement API / provider | Incompatibilité Terraform | Faible | Figer les versions Terraform et provider Google |
| Inventaire incomplet | Blocage du socle | Moyen | Vérifier `inventory.env` avant bootstrap |
| Mauvais routage Pod CIDR | Pods non joignables entre workers | Moyen | Vérifier routes statiques et `can_ip_forward` |

---

## 15. Points d’Attention

- Le choix de la zone `europe-west1-b` est un choix de laboratoire et peut être adapté.
- Le port `6443` est exposé publiquement dans la règle externe V1 ; ce point doit être restreint dans une architecture plus durable.
- Le paramètre `can_ip_forward = true` est indispensable sur les workers.
- Le provider GCP V1 reste mono-zone et sans load balancer devant l’API server.
- Le fichier `terraform.tfvars.example` n’est pas encore présent alors qu’il est encore mentionné dans certains wrappers ou documents périphériques.

---

## 16. Limites Connues de la V1

- déploiement mono-zone ;
- pas de load balancer devant l’API server ;
- pas de Cloud NAT ;
- pas d’intégration KMS pour le chiffrement etcd ;
- routage Pod CIDR reposant sur des routes statiques peu scalables ;
- niveau de maturité GCP supérieur aux autres providers, ce qui crée une asymétrie assumée dans la V1.

---

## 17. Conclusion

Le provider GCP constitue aujourd’hui le **socle de référence** pour la lecture technique du dépôt multi-cloud.

Sa valeur ne tient pas seulement à la présence de fichiers Terraform, mais à la cohérence déjà visible entre :

- réseau ;
- compute ;
- inventaire ;
- wrappers provider ;
- validations du socle.

Le rôle du LLD GCP est donc double :

- documenter fidèlement l’implémentation actuelle ;
- servir de modèle de stabilisation pour les autres providers.

---

## 18. Signature

**Auteur :** Zidane Djamal  
**Rôle :** Architecte technique senior


---
---