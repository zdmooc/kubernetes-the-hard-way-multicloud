# docs/lld/LLD-global.md

# Low Level Design (LLD) Global : Kubernetes The Hard Way Multi-Cloud

**Version :** 1.2.0  
**Auteur :** Zidane Djamal  
**Rôle :** Architecte technique senior, spécialisé en transformation Cloud Native, Kubernetes/OpenShift, modernisation de plateformes critiques, standardisation multi-environnements et industrialisation progressive.

---

## 1. Objet du document

Ce document décrit le **Low Level Design global** du dépôt `kubernetes-the-hard-way-multicloud`.

Il a pour objectif de :

- détailler l’organisation technique réelle du dépôt ;
- expliciter la séparation entre socle Kubernetes commun et overlays provider ;
- décrire les conventions partagées ;
- préciser le rôle des répertoires `docs/`, `scripts/`, `terraform/`, `inventories/` et `evidence/` ;
- formaliser le modèle d’exécution de la V1 ;
- distinguer clairement ce qui est **implémenté**, **partiellement implémenté** et **intentionnel**.

Ce LLD global complète le HLD v3 et sert de document pivot entre :

- la vision d’architecture ;
- les LLD par provider ;
- les scripts mutualisés ;
- les modules Terraform ;
- les preuves d’exécution.

---

## 2. Positionnement du LLD global

Le LLD global ne remplace pas :

- les LLD spécifiques provider (`docs/lld/gcp.md`, `aws.md`, `azure.md`, `ibmcloud.md`, `onprem.md`) ;
- les guides procéduraux du socle Kubernetes dans `docs/core/` ;
- les ADR du répertoire `docs/adr/` ;
- les README provider dans `docs/providers/<provider>/`.

Il joue un rôle de **charnière technique** entre le HLD et l’implémentation réelle.

Son principe directeur est le suivant :

> **Mutualiser le socle Kubernetes commun et isoler les écarts d’infrastructure dans des overlays provider.**

---

## 3. Structure réelle du dépôt

La structure de référence de la V1 est la suivante.

```text
kubernetes-the-hard-way-multicloud/
├── README.md
├── CONTRIBUTING.md
├── LICENSE
├── Makefile
├── docs/
│   ├── adr/
│   │   ├── ADR-001-core-vs-provider.md
│   │   ├── ADR-002-standard-topology.md
│   │   ├── ADR-003-provider-overlays.md
│   │   └── ADR-004-phased-implementation.md
│   ├── core/
│   │   ├── 01-prerequisites.md
│   │   ├── 02-jumpbox.md
│   │   ├── 03-pki.md
│   │   ├── 04-kubeconfigs.md
│   │   ├── 05-encryption.md
│   │   ├── 06-etcd.md
│   │   ├── 07-control-plane.md
│   │   ├── 08-workers.md
│   │   └── 09-smoke-tests.md
│   ├── hld/
│   │   └── HLD.md
│   ├── lld/
│   │   ├── LLD-global.md
│   │   ├── aws.md
│   │   ├── azure.md
│   │   ├── gcp.md
│   │   ├── ibmcloud.md
│   │   └── onprem.md
│   └── providers/
│       ├── aws/
│       │   └── README.md
│       ├── azure/
│       │   └── README.md
│       ├── gcp/
│       │   └── README.md
│       ├── ibmcloud/
│       │   └── README.md
│       └── onprem/
│           └── README.md
├── evidence/
│   └── README.md
├── examples/
│   └── topology-example.md
├── inventories/
│   ├── aws/
│   │   └── lab.env.example
│   ├── azure/
│   │   └── lab.env.example
│   ├── gcp/
│   │   └── lab.env.example
│   ├── ibmcloud/
│   │   └── lab.env.example
│   └── onprem/
│       └── lab.env.example
├── scripts/
│   ├── aws/
│   │   ├── cleanup.sh
│   │   └── provision.sh
│   ├── azure/
│   │   ├── cleanup.sh
│   │   └── provision.sh
│   ├── gcp/
│   │   ├── cleanup.sh
│   │   └── provision.sh
│   ├── ibmcloud/
│   │   ├── cleanup.sh
│   │   └── provision.sh
│   ├── onprem/
│   │   ├── cleanup.sh
│   │   └── prepare-hosts.sh
│   └── shared/
│       ├── check-prereqs.sh
│       ├── generate-machine-db.sh
│       ├── render-inventory.sh
│       └── smoke-tests.sh
└── terraform/
    ├── aws/
    │   ├── inventory.tpl
    │   ├── main.tf
    │   ├── outputs.tf
    │   ├── variables.tf
    │   └── versions.tf
    ├── azure/
    │   ├── inventory.tpl
    │   ├── main.tf
    │   ├── outputs.tf
    │   ├── variables.tf
    │   └── versions.tf
    ├── gcp/
    │   ├── inventory.tpl
    │   ├── main.tf
    │   ├── outputs.tf
    │   ├── variables.tf
    │   └── versions.tf
    └── ibmcloud/
        ├── inventory.tpl
        ├── main.tf
        ├── outputs.tf
        ├── variables.tf
        └── versions.tf
```

### 3.1 Lecture architecturale de cette structure

La structure est volontairement organisée selon cinq zones :

1. **`docs/`** : documentation d’architecture et guides opératoires ;
2. **`terraform/`** : provisionnement IaaS par provider ;
3. **`scripts/`** : orchestration shell minimaliste, partagée ou spécifique provider ;
4. **`inventories/`** : variables d’exemple et inventaires opérationnels ;
5. **`evidence/`** : traces de validation et preuves d’exécution.

Cette séparation facilite la relecture, la comparaison entre providers et l’industrialisation progressive.

---

## 4. Conventions de nommage

Les conventions suivantes s’appliquent à la V1.

### 4.1 Nœuds logiques

La topologie logique standard repose sur les noms suivants :

- `jumpbox` ;
- `server` ;
- `node-0` ;
- `node-1`.

Ces noms représentent un **modèle logique stable**, indépendamment du provider.

### 4.2 Ressources provider

Les ressources créées côté Terraform suivent autant que possible un préfixe lisible et stable, par exemple :

- `k8s-thw-vpc` ;
- `k8s-thw-subnet` ;
- `k8s-thw-route-node-0` ;
- `k8s-thw-jumpbox-ip`.

### 4.3 Variables shell et inventaire

Les variables d’inventaire sont écrites en majuscules avec underscore, par exemple :

- `PROVIDER` ;
- `REGION` ;
- `ZONE` ;
- `SERVER_PRIVATE_IP` ;
- `NODE_0_PUBLIC_IP` ;
- `POD_CIDR` ;
- `SERVICE_CIDR` ;
- `CLUSTER_DNS` ;
- `SSH_USER` ;
- `SSH_KEY_PATH`.

### 4.4 Fichiers Kubernetes / PKI

Les fichiers liés au socle Kubernetes suivent les conventions usuelles de `kubernetes-the-hard-way`, notamment pour :

- les certificats ;
- les kubeconfigs ;
- les manifestes de configuration ;
- les unités systemd ;
- les binaires distribués.

La granularité exacte de ces artefacts est documentée dans `docs/core/`.

---

## 5. Découpage d’architecture : Core / Providers / Inventories / Evidence

### 5.1 Couche Core

La couche Core regroupe le **socle Kubernetes agnostique à l’infrastructure** :

- prérequis ;
- jumpbox ;
- PKI ;
- kubeconfigs ;
- chiffrement des secrets ;
- etcd ;
- control plane ;
- workers ;
- smoke tests.

Dans le dépôt réel, cette couche est portée principalement par :

- `docs/core/` pour la procédure détaillée ;
- `scripts/shared/` pour les helpers mutualisés ;
- `inventories/<provider>/inventory.env` lorsqu’un inventaire opérationnel a été généré.

### 5.2 Couche Provider

Chaque provider porte la création de son infrastructure minimale et de ses variations réseau :

- GCP ;
- AWS ;
- Azure ;
- IBM Cloud ;
- on-prem.

Cette logique se répartit entre :

- `terraform/<provider>/` quand un module Terraform existe ;
- `scripts/<provider>/` pour les actions de provisioning / cleanup ou de préparation ;
- `docs/providers/<provider>/README.md` et `docs/lld/<provider>.md` pour la documentation spécifique.

### 5.3 Couche Inventaires

Les inventaires servent d’interface entre :

- les sorties du provisionnement provider ;
- les étapes du socle Kubernetes ;
- les scripts mutualisés ;
- les validations.

Cette couche distingue deux fichiers de nature différente :

- **`lab.env.example`** : exemple statique versionné, destiné à documenter les paramètres attendus ;
- **`inventory.env`** : inventaire opérationnel généré par le provisionnement lorsqu’il est implémenté pour le provider concerné.

### 5.4 Couche Evidence

Le répertoire `evidence/` reçoit les traces et validations permettant de démontrer la cohérence d’exécution :

- sorties Terraform ;
- résultats de commandes Kubernetes ;
- traces de smoke tests ;
- captures ou comptes rendus de validation ;
- artefacts de vérification.

En V1, la production de preuves est un mélange de :

- collecte manuelle ;
- journalisation shell ;
- conservation structurée des sorties.

Elle ne doit pas être présentée comme une automatisation intégrale si le dépôt ne le démontre pas encore.

---

## 6. Documentation du socle et scripts mutualisés

### 6.1 Rôle de `docs/core/`

Le répertoire `docs/core/` constitue la **référence procédurale détaillée** pour le bootstrap du cluster.

Il décrit les chapitres suivants :

1. prérequis ;
2. jumpbox ;
3. PKI ;
4. kubeconfigs ;
5. encryption ;
6. etcd ;
7. control plane ;
8. workers ;
9. smoke tests.

Cette documentation est aujourd’hui plus complète que l’automatisation shell disponible. Elle représente donc la source de vérité pour les opérations du socle.

### 6.2 Rôle de `scripts/shared/`

Le répertoire `scripts/shared/` contient des **helpers mutualisés**, et non une chaîne complète numérotée couvrant toutes les étapes du bootstrap.

Scripts actuellement visibles :

- `check-prereqs.sh` : vérification de la présence d’outils requis tels que `cfssl`, `cfssljson`, `kubectl`, `ssh`, `scp`, `openssl` ;
- `generate-machine-db.sh` : génération d’un mapping simple IP privée / hostname à partir des variables chargées depuis l’inventaire ;
- `render-inventory.sh` : validation du contenu d’un inventaire opérationnel déjà chargé dans l’environnement ;
- `smoke-tests.sh` : exécution d’un sous-ensemble de validations fonctionnelles du cluster.

### 6.3 Conséquence sur la lecture du dépôt

Il est important de distinguer :

- la **procédure complète de bootstrap**, documentée dans `docs/core/` ;
- les **helpers shell disponibles**, concentrés dans `scripts/shared/` ;
- les **scripts provider**, concentrés dans `scripts/<provider>/`.

La V1 ne doit donc pas être décrite comme un ensemble entièrement automatisé par des scripts `01-*` à `11-*` dans un répertoire `scripts/core/`, car cette structure n’existe pas dans le dépôt réel.

---

## 7. Logique Terraform réelle

### 7.1 Structure attendue des modules cloud

Pour les providers cloud disposant d’un module Terraform, la structure observée est la suivante :

- `main.tf` ;
- `variables.tf` ;
- `outputs.tf` ;
- `versions.tf` ;
- `inventory.tpl`.

Cette structure est utilisée pour :

- définir le provider ;
- créer le réseau minimal ;
- créer les IP publiques ou privées nécessaires ;
- créer les instances ;
- déclarer les outputs utiles ;
- générer un `inventory.env` lorsqu’une génération locale est implémentée.

### 7.2 Cas du provider on-prem

La V1 ne comporte **pas de module Terraform `terraform/onprem/`**.

Le provider on-prem repose sur :

- un inventaire maîtrisé ;
- une préparation des hôtes via `scripts/onprem/prepare-hosts.sh` ;
- une logique plus documentaire et opératoire que Terraform dans l’état actuel du dépôt.

### 7.3 Cas GCP

Le provider GCP est actuellement le plus concret et sert de **point d’appui principal**.

Le module `terraform/gcp/` montre déjà :

- la création du réseau ;
- la création des règles de firewall ;
- la réservation d’IP publiques ;
- la création des instances `jumpbox`, `server`, `node-0`, `node-1` ;
- la création des routes statiques pour les Pod CIDR ;
- la génération d’un fichier `inventories/gcp/inventory.env` via `local_file` et `templatefile`.

### 7.4 Limites actuelles à expliciter

Le LLD doit refléter également les écarts présents dans le dépôt :

- certains scripts provider référencent `terraform.tfvars.example` alors que ce fichier n’est pas encore présent ;
- tous les providers ne montrent pas le même niveau de maturité fonctionnelle ;
- la cohérence doc ↔ scripts ↔ Terraform reste un chantier normal de stabilisation de V1.

---

## 8. Matrice de statut par provider

Cette matrice donne une lecture synthétique de la V1. Les statuts retenus sont :

- **Fait** ;
- **Partiel** ;
- **À confirmer**.

| Capacité | GCP | AWS | Azure | IBM Cloud | On-Prem |
|---|---|---|---|---|---|
| Structure `docs/lld/<provider>.md` présente | Fait | Fait | Fait | Fait | Fait |
| README provider présent | Fait | Fait | Fait | Fait | Fait |
| Module Terraform présent | Fait | Fait | Fait | Fait | Non applicable en V1 |
| Wrapper `provision.sh` / `cleanup.sh` présent | Fait | Fait | Fait | Fait | Partiel |
| Génération `inventory.env` visible | Fait | Fait | À confirmer | À confirmer | Non applicable / manuel |
| Topologie standard `jumpbox/server/node-0/node-1` | Fait | Fait | À confirmer | À confirmer | Intentionnel / à adapter |
| Scripts shared consommables | Fait | Partiel | Partiel | Partiel | Partiel |
| Smoke tests exploitables | Fait | Partiel | Partiel | Partiel | Partiel |
| Niveau global de validation V1 | Référence | À consolider | À consolider | À consolider | Documentaire / opératoire |

### 8.1 Lecture de la matrice

Le tableau ne mesure pas uniquement la présence de fichiers. Il indique aussi le **niveau de confiance** dans l’exploitabilité réelle.

En V1 :

- **GCP** est le provider de référence ;
- **AWS** est présent structurellement et techniquement cohérent, avec génération d’inventaire visible ;
- **Azure / IBM Cloud** sont présents structurellement mais demandent encore une validation détaillée ;
- **on-prem** suit une logique distincte, plus proche d’un runbook préparatoire que d’un provider Terraform complet.

---

## 9. Logique des variables et des inventaires

### 9.1 Deux catégories de variables

Les variables du dépôt se répartissent en deux familles.

#### A. Variables d’infrastructure

Elles pilotent la création des ressources provider et sont portées par :

- `variables.tf` ;
- les valeurs par défaut Terraform ;
- les éventuels fichiers `terraform.tfvars` locaux ;
- les variables d’environnement utilisées par la CLI Terraform ou le provider.

Exemples :

- projet ou subscription ;
- région ;
- zone ;
- type de machine ;
- utilisateur SSH ;
- chemin de clé publique.

#### B. Variables d’exécution du socle

Elles représentent la vue opérationnelle du cluster en cours de bootstrap et sont portées par l’inventaire d’exécution.

Exemples :

- `SERVER_PRIVATE_IP` ;
- `NODE_0_PRIVATE_IP` ;
- `NODE_1_PRIVATE_IP` ;
- `JUMPBOX_PUBLIC_IP` ;
- `SERVICE_CIDR` ;
- `POD_CIDR` ;
- `CLUSTER_DNS` ;
- `SSH_USER` ;
- `SSH_KEY_PATH`.

### 9.2 `lab.env.example` vs `inventory.env`

La distinction suivante doit rester explicite dans tous les LLD.

#### `lab.env.example`

- fichier versionné ;
- statique ;
- sert de modèle de saisie et de documentation ;
- présent pour tous les providers dans `inventories/<provider>/`.

#### `inventory.env`

- fichier d’exécution ;
- généré ou maintenu localement selon le provider ;
- non destiné à être présenté comme présent par défaut dans Git ;
- consommé par les scripts et opérations du socle lorsqu’il existe.

### 9.3 Exemple de contenu d’inventaire opérationnel

```bash
PROVIDER="gcp"
REGION="europe-west1"
ZONE="europe-west1-b"

JUMPBOX_PUBLIC_IP="34.123.45.67"
SERVER_PUBLIC_IP="34.123.45.68"
NODE_0_PUBLIC_IP="34.123.45.69"
NODE_1_PUBLIC_IP="34.123.45.70"

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

Cet exemple représente une **forme cible crédible** de l’inventaire opérationnel. Il ne signifie pas que tous les providers génèrent déjà exactement le même contenu au même niveau de maturité.

---

## 10. Baseline technique de référence V1

La V1 doit s’appuyer sur une baseline explicite pour éviter les ambiguïtés entre valeurs de démonstration et référence opératoire.

### 10.1 Versions de référence

Les versions de référence visibles ou utilisées dans le dépôt V1 sont les suivantes :

| Composant | Version de référence V1 |
|---|---|
| Kubernetes | `1.29.2` |
| etcd | `3.5.12` |
| containerd | `1.7.13` |
| CNI plugins | `1.4.0` |
| runc | `1.1.12` |
| OS cible des VM cloud observées | Ubuntu 22.04 LTS |

### 10.2 Paramètres réseau logiques de référence

| Élément | Valeur de référence V1 |
|---|---|
| Réseau / Subnet logique cloud | `10.240.0.0/24` |
| Pod CIDR global | `10.200.0.0/16` |
| Pod CIDR `node-0` | `10.200.0.0/24` |
| Pod CIDR `node-1` | `10.200.1.0/24` |
| Service CIDR | `10.32.0.0/24` |
| Cluster DNS | `10.32.0.10` |

### 10.3 Rôle de cette baseline

Cette baseline :

- fixe le cadre de compatibilité documentaire ;
- facilite la relecture des inventaires et scripts ;
- permet d’identifier plus rapidement les écarts lors des validations provider.

Elle pourra évoluer dans les versions futures, mais doit rester stable pendant la consolidation de la V1.

---

## 11. Modèle d’exécution de la V1

Le cycle de vie logique de la V1 est le suivant.

### 11.1 Préparation provider

L’utilisateur :

- choisit un provider ;
- renseigne ses variables locales ;
- prépare son contexte cloud ou on-prem ;
- vérifie ses prérequis système.

### 11.2 Provisionnement infrastructure

Selon le provider, l’utilisateur :

- exécute Terraform directement dans `terraform/<provider>/` ;
- ou passe par `scripts/<provider>/provision.sh` lorsque ce wrapper est utilisé ;
- ou, pour on-prem, prépare les hôtes avec `scripts/onprem/prepare-hosts.sh` et un inventaire maîtrisé.

### 11.3 Production de l’inventaire opérationnel

Lorsque le provider l’implémente, le provisionnement produit un `inventory.env` dans `inventories/<provider>/`.

Cet inventaire permet ensuite de :

- valider les variables attendues ;
- préparer certains mappings opératoires ;
- alimenter les étapes du socle Kubernetes.

### 11.4 Exécution du socle Kubernetes

L’exécution du socle repose principalement sur `docs/core/`.

Selon le niveau d’automatisation disponible, l’utilisateur exécute :

- les commandes documentées dans `docs/core/` ;
- les helpers de `scripts/shared/` ;
- les actions nécessaires depuis la jumpbox, le poste opérateur ou les hôtes du cluster.

### 11.5 Validation

La validation repose sur :

- les procédures décrites dans `docs/core/09-smoke-tests.md` ;
- le script `scripts/shared/smoke-tests.sh` pour la partie automatisée actuellement disponible ;
- la conservation des preuves dans `evidence/`.

### 11.6 Cleanup

Le nettoyage s’effectue côté provider :

- via `terraform destroy` ou `scripts/<provider>/cleanup.sh` lorsque Terraform est utilisé ;
- via nettoyage des hôtes et artefacts dans le cas on-prem.

### 11.7 Conséquence d’architecture

La V1 doit donc être comprise comme un **laboratoire expert structuré**, avec :

- une documentation forte ;
- un socle partiellement outillé ;
- une exécution encore largement guidée ;
- une industrialisation progressive.

---

## 12. Logique d’injection IP / hostnames / SANs

La génération de la PKI et de certains artefacts du socle dépend directement des informations contenues dans l’inventaire opérationnel.

Les variables les plus structurantes sont notamment :

- `SERVER_PRIVATE_IP` ;
- `SERVER_PUBLIC_IP` si l’API est exposée de cette manière ;
- `JUMPBOX_PUBLIC_IP` ;
- `NODE_0_PRIVATE_IP` ;
- `NODE_1_PRIVATE_IP` ;
- `SERVICE_CIDR` ;
- les hostnames logiques (`server`, `node-0`, `node-1`).

Ces informations sont utilisées pour :

- construire les CSR ;
- définir les Subject Alternative Names des certificats ;
- alimenter les kubeconfigs ;
- vérifier la cohérence des accès SSH et des validations réseau.

### 12.1 Point d’attention documentaire

Dans le dépôt réel actuel, la logique PKI est surtout documentée dans `docs/core/03-pki.md`. Le LLD global ne doit donc pas faire croire qu’un script unique de type `02-pki.sh` existe déjà et constitue la seule implémentation.

Il est plus exact de dire que :

- la **dépendance aux IP et hostnames est réelle** ;
- l’**inventaire opérationnel en est le support naturel** ;
- la **forme exacte d’automatisation** peut varier selon le niveau de maturité du dépôt.

---

## 13. Vue synthétique des artefacts du socle

Le LLD global fixe ici une vue synthétique des artefacts majeurs, sans remplacer le détail de `docs/core/`.

| Artefact | Généré / préparé depuis | Destination cible principale | Usage |
|---|---|---|---|
| Certificats CA et certificats composants | Poste opérateur / jumpbox selon procédure | Jumpbox, server, workers selon besoin | TLS, authentification, sécurisation des flux |
| Kubeconfigs | Poste opérateur / jumpbox selon procédure | Jumpbox et nœuds concernés | Authentification des composants Kubernetes |
| `encryption-config.yaml` | Poste opérateur / jumpbox | `server` | Chiffrement des secrets dans etcd |
| Binaires Kubernetes / container runtime | Dépôt externe ou transfert opérateur | `server`, `node-0`, `node-1` | Exécution des services cluster |
| Unités systemd / fichiers de conf | Préparés selon `docs/core/` | `server`, `node-0`, `node-1` | Démarrage et gestion des composants |
| `inventory.env` | Terraform ou préparation manuelle selon provider | `inventories/<provider>/` puis environnement shell | Contrat d’interface entre infra et socle |
| `machines.txt` | `scripts/shared/generate-machine-db.sh` | Répertoire de travail opérateur | Mapping simple IP / hostname |

### 13.1 Limite volontaire

Ce tableau donne une **vue de gouvernance technique**. Il n’a pas vocation à documenter exhaustivement tous les chemins absolus, permissions Unix ou propriétaires de fichiers ; ces détails relèvent davantage des guides opératoires détaillés par chapitre.

---

## 14. Flux réseau et ports de référence

Le LLD global fige ici une vue compacte des flux les plus structurants de la V1.

| Source | Destination | Port / Protocole | Justification |
|---|---|---|---|
| Poste opérateur | Jumpbox | `22/TCP` | Accès SSH d’administration |
| Jumpbox | `server` | `22/TCP` | Bootstrap et administration du control plane |
| Jumpbox | `node-0`, `node-1` | `22/TCP` | Bootstrap et administration des workers |
| `node-0`, `node-1` | API Server (`server`) | `6443/TCP` | Enregistrement kubelet, trafic Kubernetes |
| API Server (`server`) | etcd local | `2379/TCP` | Accès datastore cluster |
| API Server / opérateur | Kubelet workers | flux Kubernetes sécurisés | `exec`, logs, port-forward, supervision |
| Jumpbox / opérateur | Worker NodePort | port dynamique `30000-32767/TCP` | Test d’exposition service |
| Nœuds du cluster | Nœuds du cluster | flux inter-nœuds requis | Routage Pod-to-Pod, services, runtime |

### 14.1 Lecture de cette table

Cette table ne remplace pas une DAT réseau complète. Elle sert à :

- aligner les LLD provider ;
- guider les règles firewall / security groups ;
- expliciter les flux minimums à autoriser pour les validations V1.

---

## 15. Stratégie de preuves d’exécution

### 15.1 Principe

Chaque étape importante doit pouvoir être reliée à une preuve exploitable.

Exemples :

- résultat de `terraform apply` ;
- rendu de l’inventaire ;
- contrôle des binaires et services ;
- état d’etcd ;
- état du control plane ;
- état des nœuds ;
- exécution des smoke tests ;
- traces de cleanup.

### 15.2 Nature des preuves en V1

La V1 repose sur une approche pragmatique :

- commandes copiées dans `evidence/` ;
- logs shell ;
- captures d’écran si nécessaire ;
- sorties `kubectl` ;
- artefacts de validation.

Le dépôt ne doit pas prétendre qu’une collecte uniforme et complètement automatisée existe déjà pour toutes les étapes si cela n’est pas visible.

### 15.3 Exemples de preuves attendues

Exemples de fichiers ou familles de preuves :

- `evidence/terraform-apply-<provider>.txt` ;
- `evidence/inventory-<provider>.txt` ;
- `evidence/etcd-health.txt` ;
- `evidence/nodes-ready.txt` ;
- `evidence/smoke-tests-results.txt` ;
- `evidence/cleanup-<provider>.txt`.

Ces noms sont des conventions recommandées, pas une garantie que tous ces fichiers soient déjà produits automatiquement par le dépôt.

---

## 16. Stratégie de validation

### 16.1 Objectif

Les smoke tests vérifient que le cluster est **fonctionnel au niveau minimal attendu** :

- control plane accessible ;
- nœuds présents et `Ready` ;
- déploiement possible ;
- exécution de commande dans un pod ;
- exposition réseau minimale ;
- comportements fondamentaux du cluster observables.

### 16.2 Référence documentaire

La référence détaillée reste `docs/core/09-smoke-tests.md`.

Ce document couvre notamment :

- chiffrement au repos ;
- déploiement ;
- port-forwarding ;
- logs ;
- exec ;
- exposition par Service / NodePort.

### 16.3 Couverture scriptée actuellement visible

Le script `scripts/shared/smoke-tests.sh` automatise actuellement un sous-ensemble visible de ces validations :

- `kubectl get nodes -o wide` ;
- `kubectl get componentstatuses` ;
- création d’un déploiement Nginx ;
- attente de disponibilité ;
- `kubectl exec` dans le pod ;
- exposition via `NodePort` ;
- suggestion de test `curl` vers un worker.

### 16.4 Conséquence sur le LLD

Le LLD global doit distinguer :

- la **stratégie de validation cible** décrite par la documentation ;
- la **couverture automatisée réellement visible** dans `scripts/shared/smoke-tests.sh`.

Il ne faut pas présenter l’intégralité des validations comme déjà automatisées si elles relèvent encore de procédures manuelles ou semi-guidées.

---

## 17. Gestion d’erreur et stratégie de reprise

La V1 doit rester exploitable même en cas d’échec partiel. Cette section fixe des règles minimales de reprise.

### 17.1 Échec Terraform partiel

Cas typique :

- ressources créées partiellement ;
- state Terraform cohérent mais infrastructure incomplète ;
- `inventory.env` absent ou incomplet.

Réponse attendue :

- analyser les outputs Terraform et les erreurs provider ;
- corriger les variables ou quotas ;
- relancer `terraform apply` si le state reste cohérent ;
- exécuter `cleanup.sh` ou `terraform destroy` si l’environnement doit être recréé proprement.

### 17.2 Inventaire incomplet ou incohérent

Cas typique :

- variable requise absente ;
- IP publique ou privée incorrecte ;
- divergence entre Terraform et inventaire sourcé.

Réponse attendue :

- vérifier le rendu de `inventory.tpl` et les outputs ;
- utiliser `scripts/shared/render-inventory.sh` pour contrôler les variables ;
- régénérer l’inventaire avant toute poursuite du bootstrap.

### 17.3 PKI générée avec mauvaise IP ou mauvais SAN

Cas typique :

- erreur TLS vers l’API server ;
- kubeconfig invalide ;
- handshake refusé.

Réponse attendue :

- corriger les variables d’inventaire ;
- regénérer les CSR et certificats concernés ;
- redistribuer les artefacts dépendants ;
- revalider avant de poursuivre.

### 17.4 Workers non `Ready`

Cas typique :

- kubelet non enregistré ;
- problème de certificats ;
- problème réseau ;
- container runtime non opérationnel.

Réponse attendue :

- vérifier état des services système ;
- contrôler les kubeconfigs et certificats ;
- valider la joignabilité de l’API server ;
- vérifier le routage Pod CIDR et les règles firewall ;
- rejouer uniquement l’étape concernée si possible.

### 17.5 Smoke tests en échec

Cas typique :

- déploiement qui ne devient pas `Available` ;
- `exec` ou `logs` en erreur ;
- NodePort non joignable.

Réponse attendue :

- identifier si l’échec relève du control plane, du réseau, du kubelet ou du proxying ;
- conserver les preuves d’erreur dans `evidence/` ;
- corriger la cause avant de rejouer la validation.

### 17.6 Principe de reprise général

La règle de V1 est la suivante :

- **corriger au plus près de la cause** ;
- **éviter les destructions inutiles** ;
- **rejouer l’étape minimale nécessaire** ;
- **reconstruire complètement seulement si la cohérence globale est perdue**.

---

## 18. Mini-table de traçabilité HLD → LLD → repo → evidence

Cette table donne une vue courte de la traçabilité attendue.

| Sujet d’architecture | Section LLD globale | Zone du repo | Preuve attendue |
|---|---|---|---|
| Séparation core / provider | Sections 2, 5 | `docs/adr/`, `docs/core/`, `terraform/`, `scripts/` | Arborescence validée, revue documentaire |
| Topologie standard | Sections 4, 7, 14 | Terraform provider, inventaires | Inventaire rendu, IP et hostnames visibles |
| Contrat d’inventaire | Sections 5, 9 | `inventories/`, `inventory.tpl`, scripts shared | `inventory.env`, validation shell |
| Bootstrap du socle | Sections 6, 11, 12 | `docs/core/`, `scripts/shared/` | Traces d’exécution des étapes core |
| Validation cluster | Sections 15, 16 | `docs/core/09-smoke-tests.md`, `scripts/shared/smoke-tests.sh` | `kubectl get nodes`, résultats smoke tests |
| Industrialisation progressive | Sections 7, 8, 17, 19 | LLD provider, scripts, backlog V1 | Écarts documentés, actions de stabilisation |

---

## 19. Vue d’implémentation par provider

### 19.1 GCP

- provider le plus concret à ce stade ;
- topologie et réseau déjà détaillés dans Terraform ;
- génération d’un `inventory.env` déjà visible ;
- bon candidat pour la stabilisation complète de la V1.

### 19.2 AWS

- overlay cohérent dans la structure du dépôt ;
- module Terraform présent ;
- wrappers `provision.sh` / `cleanup.sh` présents ;
- génération d’inventaire visible ;
- niveau de complétude à confirmer par validation détaillée du provider.

### 19.3 Azure

- overlay cohérent dans la structure du dépôt ;
- module Terraform présent ;
- wrappers provider présents ;
- niveau de maturité à aligner progressivement sur le provider de référence.

### 19.4 IBM Cloud

- overlay cohérent dans la structure du dépôt ;
- module Terraform présent ;
- wrappers provider présents ;
- trajectoire comparable à AWS et Azure, avec validation à consolider.

### 19.5 On-Prem

- pas de module Terraform dédié en V1 ;
- logique reposant sur inventaire et préparation des hôtes ;
- intérêt fort pour la comparabilité architecturale, même avec une automatisation plus faible.

---

## 20. Écarts connus et dette documentaire / technique

Les écarts suivants sont connus et doivent être assumés dans la lecture de la V1.

### 20.1 Scripts provider et `terraform.tfvars.example`

Certains scripts `provision.sh` référencent `terraform.tfvars.example`, alors que ces fichiers ne sont pas encore présents.

Conséquence :

- la documentation doit l’indiquer honnêtement ;
- une harmonisation future des fichiers d’exemple Terraform est souhaitable.

### 20.2 Références obsolètes à `scripts/core/`

Certaines formulations historiques décrivent un répertoire `scripts/core/` ou une chaîne `01-*` à `11-*`.

Cette représentation doit être corrigée au profit de :

- `docs/core/` pour les étapes détaillées ;
- `scripts/shared/` pour les helpers mutualisés ;
- `scripts/<provider>/` pour le provisioning / cleanup provider.

### 20.3 Référence obsolète dans les smoke tests

Le document `docs/core/09-smoke-tests.md` doit être réaligné avec le chemin réel du script de validation partagé lorsque nécessaire.

### 20.4 Maturité hétérogène des providers

Tous les providers ne sont pas au même niveau de complétude. Le dépôt doit rester crédible en assumant cette asymétrie plutôt qu’en la masquant.

---

## 21. Trajectoire d’évolution

### 21.1 V1

La V1 vise :

- la cohérence documentaire ;
- un provider de référence exécutable ;
- un découpage clair du dépôt ;
- des inventaires cohérents ;
- des preuves exploitables ;
- une base saine pour industrialisation ultérieure.

### 21.2 V2

La V2 pourra viser :

- stabilisation renforcée des scripts mutualisés ;
- meilleure cohérence doc ↔ code ;
- validation CI minimale ;
- automatisation plus forte des opérations du socle ;
- rationalisation des fichiers d’exemple provider ;
- meilleure couverture des providers non GCP.

### 21.3 V3

Les évolutions plus ambitieuses pourront inclure :

- multi-control-plane / HA ;
- sécurité renforcée ;
- observabilité ;
- pipelines CI de validation ;
- extension on-prem ;
- benchmark comparatif de coûts ;
- déclinaison OpenShift.

---

## 22. Conclusion

Le dépôt `kubernetes-the-hard-way-multicloud` doit être lu comme un **actif d’architecture technique multi-cloud**, conçu pour :

- rendre visible le fonctionnement interne d’un cluster Kubernetes monté « hard way » ;
- comparer plusieurs providers autour d’une topologie logique stable ;
- structurer un dépôt sérieux, relisible et industrialisable ;
- faire converger documentation, code et preuves d’exécution.

La valeur du LLD global repose sur trois exigences :

- **fidélité au dépôt réel** ;
- **distinction explicite entre implémenté et intentionnel** ;
- **alignement avec le HLD et les overlays provider**.

---

## 23. Signature

**Auteur :** Zidane Djamal  
**Rôle :** Architecte technique senior  
**Positionnement :** transformation Cloud Native, Kubernetes/OpenShift, standardisation multi-environnements, industrialisation progressive.


---
---