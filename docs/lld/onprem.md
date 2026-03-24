
# docs/lld/onprem.md

# Low Level Design (LLD) Provider : On-Premises

**Version :** 1.1.0  
**Auteur :** Zidane Djamal  
**Rôle :** Architecte technique senior

---

## 1. Présentation du Provider

L’environnement On-Premises (on-prem) représente le déploiement de Kubernetes sur une infrastructure locale, sans dépendance à un fournisseur Cloud public. Ce scénario est pertinent pour les environnements souverains, les laboratoires locaux, les contextes déconnectés (air-gapped), ou les architectures techniques souhaitant conserver une maîtrise complète de l’infrastructure hôte.

Dans l’état actuel du dépôt, le provider on-prem ne repose pas sur un module Terraform dédié. Il est modélisé comme un **mode d’exécution local** fondé sur :

- un inventaire local dans `inventories/onprem/` ;
- des scripts d’assistance dans `scripts/onprem/` ;
- la conservation de la topologie logique standard (`jumpbox`, `server`, `node-0`, `node-1`) ;
- un bootstrap Kubernetes réalisé ensuite via `docs/core/` et les scripts mutualisés.

L’overlay on-prem ne crée donc pas automatiquement toute l’infrastructure locale dans le dépôt actuel. Il prépare et structure un environnement local déjà disponible ou créé hors du dépôt.

---

## 2. Hypothèses Spécifiques

- L’utilisateur dispose d’un hôte local ou d’une plateforme de virtualisation capable d’exécuter quatre machines nommées `jumpbox`, `server`, `node-0` et `node-1`.
- Les VMs peuvent être créées hors du dépôt via l’hyperviseur ou l’outillage local retenu.
- L’utilisateur dispose d’un accès SSH par clé vers ces machines.
- Le plan d’adressage suit le modèle logique du dépôt :
  - `10.240.0.10` pour `jumpbox`
  - `10.240.0.11` pour `server`
  - `10.240.0.20` pour `node-0`
  - `10.240.0.21` pour `node-1`
- L’inventaire `inventories/onprem/inventory.env` est préparé localement à partir de `inventories/onprem/lab.env.example` ou d’un mécanisme équivalent.
- Si l’environnement local utilise `libvirt/virsh`, le script `scripts/onprem/cleanup.sh` peut détruire les VMs et le réseau virtuel associés.
- L’utilisateur dispose de privilèges suffisants sur les nœuds pour exécuter les opérations système requises par Kubernetes.

---

## 3. Architecture Réseau

### 3.1. Composants Réseau

Dans la V1 actuelle du dépôt, l’architecture réseau on-prem est définie surtout comme un **contrat logique** et non comme une création automatique complète.

Les éléments visibles ou implicites sont les suivants :

| Composant | Nom / valeur | Description |
| :--- | :--- | :--- |
| **Réseau local du cluster** | `10.240.0.0/24` | Réseau des VMs du cluster |
| **Réseau libvirt potentiel** | `k8s-thw-net` | Nom visible dans le script `cleanup.sh` lorsqu’un environnement `virsh` est utilisé |
| **Adressage statique** | Oui | Les IP sont supposées stables et connues via l’inventaire |
| **Accès externe** | Direct depuis l’hôte local | Il n’y a pas de distinction publique/privée au sens cloud |

### 3.2. Plan d’Adressage

| Bloc CIDR | Usage |
| :--- | :--- |
| `10.240.0.0/24` | Réseau local des nœuds |
| `10.240.0.10` | `jumpbox` |
| `10.240.0.11` | `server` |
| `10.240.0.20` | `node-0` |
| `10.240.0.21` | `node-1` |
| `10.200.0.0/16` | Pod CIDR global |
| `10.200.0.0/24` | Pod CIDR node-0 |
| `10.200.1.0/24` | Pod CIDR node-1 |
| `10.32.0.0/24` | Service CIDR |

### 3.3. Routage du Pod CIDR

Le routage Pod-to-Pod reste une exigence du socle Kubernetes, mais il n’est pas créé automatiquement par les scripts `scripts/onprem/` actuellement visibles.

Le LLD on-prem fixe donc la cible logique suivante :

| Route logique | Destination | Next Hop |
| :--- | :--- | :--- |
| route vers pods node-0 | `10.200.0.0/24` | `10.240.0.20` |
| route vers pods node-1 | `10.200.1.0/24` | `10.240.0.21` |

La mise en œuvre exacte dépend du mode de virtualisation retenu et des procédures du socle.

### 3.4. Point d’Attention Réseau

Dans la V1 actuelle, le dépôt ne standardise pas complètement la création du bridge, du NAT ou du DHCP local. Ces choix restent dépendants de l’environnement d’exécution et doivent être assumés comme tels dans le LLD.

---

## 4. Architecture Compute

### 4.1. Nœuds logiques

Le dépôt standardise avant tout les **noms de nœuds** et les **IP attendues**, pas un dimensionnement automatisé uniforme des VMs on-prem.

| Hostname | Rôle | IP attendue | Accès |
| :--- | :--- | :--- | :--- |
| `jumpbox` | point d’entrée opérateur | `10.240.0.10` | SSH depuis l’hôte |
| `server` | control plane | `10.240.0.11` | SSH via l’hôte ou la jumpbox |
| `node-0` | worker | `10.240.0.20` | SSH via l’hôte ou la jumpbox |
| `node-1` | worker | `10.240.0.21` | SSH via l’hôte ou la jumpbox |

### 4.2. Ce que le dépôt impose réellement

Les éléments réellement visibles dans les scripts on-prem sont les suivants :

- présence logique de `jumpbox`, `server`, `node-0`, `node-1` ;
- usage d’un accès SSH par clé ;
- préparation système de `server`, `node-0` et `node-1` via `scripts/onprem/prepare-hosts.sh` ;
- nettoyage des VMs et du réseau local via `scripts/onprem/cleanup.sh` lorsque `virsh` est disponible.

### 4.3. Ce que le dépôt n’impose pas encore

La V1 actuelle ne fixe pas dans le code :

- un nombre standard de vCPU ;
- une quantité standard de RAM ;
- une taille standard de disque ;
- un mécanisme unique de création des VMs.

Ces paramètres relèvent donc du runbook local ou du lab de l’utilisateur.

---

## 5. Sécurité

### 5.1. Modèle de sécurité V1

En environnement on-prem V1, il n’existe pas de Security Group managé comme sur les providers cloud. La sécurité repose principalement sur :

- l’isolation du réseau local du cluster ;
- l’authentification SSH par clé ;
- la maîtrise de l’hôte de virtualisation ;
- les privilèges système sur les nœuds.

### 5.2. Principes de Sécurité V1

Pour la V1, le dépôt ne montre pas de durcissement réseau on-prem automatisé de type :

- firewall local standardisé ;
- segmentation réseau avancée ;
- chiffrement disque ;
- SELinux/AppArmor spécifique au provider.

Le LLD doit donc présenter la sécurité on-prem comme **simple et maîtrisée localement**, sans la survendre.

---

## 6. Accès SSH

L’accès SSH on-prem repose sur les variables d’inventaire `SSH_USER` et `SSH_KEY_PATH`.

### 6.1. Principes

- `inventories/onprem/lab.env.example` fixe aujourd’hui `SSH_USER="ubuntu"` ;
- la clé privée utilisée côté opérateur est `~/.ssh/id_ed25519` dans l’exemple versionné ;
- `scripts/onprem/prepare-hosts.sh` utilise explicitement `SSH_USER`, `SSH_KEY_PATH` et les IP privées des nœuds.

### 6.2. Rôle de la jumpbox

La `jumpbox` reste conservée dans le modèle on-prem pour rester cohérente avec les autres providers, même si, techniquement, l’hôte local peut souvent joindre directement tous les nœuds.

### 6.3. Portée du script `prepare-hosts.sh`

Le script `scripts/onprem/prepare-hosts.sh` prépare :

- `server`
- `node-0`
- `node-1`

Il ne prépare pas `jumpbox`, ce qui est cohérent avec son rôle de machine d’accès et d’orchestration.

---

## 7. IP / DNS

### 7.1. Adresses IP

Dans la convention on-prem du dépôt :

- il n’y a pas de vraie séparation cloud entre IP publique et IP privée ;
- les variables `*_PUBLIC_IP` et `*_PRIVATE_IP` portent la même valeur dans l’exemple versionné ;
- `REGION` et `ZONE` valent `local`.

### 7.2. Résolution DNS

Le dépôt ne montre pas de mécanisme on-prem automatisé complet de résolution DNS locale. En pratique, la résolution peut reposer sur :

- `/etc/hosts` ;
- DNS local du lab ;
- conventions de l’hyperviseur.

Le LLD ne doit pas présenter une automatisation DNS complète si elle n’est pas visible dans les scripts réels.

---

## 8. Variables Attendues

### 8.1. Positionnement V1

La V1 on-prem du dépôt ne s’appuie pas sur un `variables.tf` on-prem visible dans le repository. Le contrat d’entrée réellement visible est d’abord l’inventaire local.

### 8.2. Variables d’inventaire attendues

Le fichier `inventories/onprem/lab.env.example` montre les variables attendues :

| Variable | Exemple | Description |
| :--- | :--- | :--- |
| `PROVIDER` | `onprem` | Provider logique |
| `REGION` | `local` | Région logique locale |
| `ZONE` | `local` | Zone logique locale |
| `JUMPBOX_PUBLIC_IP` | `10.240.0.10` | IP de la jumpbox |
| `SERVER_PUBLIC_IP` | `10.240.0.11` | IP du server |
| `NODE_0_PUBLIC_IP` | `10.240.0.20` | IP de node-0 |
| `NODE_1_PUBLIC_IP` | `10.240.0.21` | IP de node-1 |
| `JUMPBOX_PRIVATE_IP` | `10.240.0.10` | IP privée jumpbox |
| `SERVER_PRIVATE_IP` | `10.240.0.11` | IP privée server |
| `NODE_0_PRIVATE_IP` | `10.240.0.20` | IP privée node-0 |
| `NODE_1_PRIVATE_IP` | `10.240.0.21` | IP privée node-1 |
| `POD_CIDR` | `10.200.0.0/16` | Pod CIDR global |
| `SERVICE_CIDR` | `10.32.0.0/24` | Service CIDR |
| `CLUSTER_DNS` | `10.32.0.10` | DNS cluster |
| `SSH_USER` | `ubuntu` | Utilisateur SSH |
| `SSH_KEY_PATH` | `~/.ssh/id_ed25519` | Clé privée SSH |

### 8.3. `lab.env.example` vs `inventory.env`

Le provider on-prem suit la distinction standard du dépôt :

- `inventories/onprem/lab.env.example` : exemple versionné ;
- `inventories/onprem/inventory.env` : fichier d’exécution local, créé ou adapté par l’utilisateur selon son environnement.

---

## 9. Structure Réelle du Provider On-Prem

```text
docs/providers/onprem/
└── README.md

inventories/onprem/
└── lab.env.example

scripts/onprem/
├── cleanup.sh
└── prepare-hosts.sh
```

### 9.1. Rôle des éléments réels

- `docs/providers/onprem/README.md` : documentation provider ;
- `inventories/onprem/lab.env.example` : contrat d’inventaire versionné ;
- `scripts/onprem/prepare-hosts.sh` : préparation système des nœuds ;
- `scripts/onprem/cleanup.sh` : nettoyage local orienté `virsh` si disponible.

### 9.2. Point d’attention documentaire

Le dépôt réel ne montre pas, à ce stade :

- `terraform/onprem/` ;
- `network.tf` ;
- `compute.tf` ;
- `cloud_init.tf` ;
- `templates/` ;
- `inventory.tf` ;
- `scripts/providers/onprem/`.

Le LLD on-prem doit donc être réaligné sur cette structure réelle et ne pas continuer à décrire un provider Terraform on-prem absent du dépôt.

---

## 10. Structure Scripts Réelle

```text
scripts/onprem/
├── cleanup.sh
└── prepare-hosts.sh
```

### 10.1. `prepare-hosts.sh`

Ce script :

- exige qu’un inventaire soit déjà sourcé ;
- prépare `server`, `node-0` et `node-1` ;
- désactive le swap ;
- active `net.ipv4.ip_forward=1` ;
- charge `overlay` et `br_netfilter`.

### 10.2. `cleanup.sh`

Ce script :

- propose une confirmation interactive ;
- tente un cleanup via `virsh` si `virsh` est disponible ;
- détruit les domaines `jumpbox`, `server`, `node-0`, `node-1` ;
- supprime le réseau `k8s-thw-net` ;
- supprime `inventories/onprem/inventory.env`.

### 10.3. Interprétation

La V1 on-prem actuelle est donc un provider **assisté par scripts**, pas un provider complètement provisionné par le dépôt.

---

## 11. Exemple d'Inventory

```bash
PROVIDER="onprem"
REGION="local"
ZONE="local"

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

En on-prem V1, les variables `*_PUBLIC_IP` et `*_PRIVATE_IP` portent la même valeur dans l’exemple versionné, car il n’y a pas de séparation cloud native entre IP publique et IP privée.

---

## 12. Flux d'Exécution

Le flux de déploiement on-prem V1 peut être résumé ainsi :

1. **Préparation locale**
   - disposer des VMs locales ou de l’environnement de virtualisation nécessaire ;
   - vérifier les accès SSH, les IPs et les ressources de l’hôte.

2. **Préparation de l’inventaire**
   - créer ou adapter `inventories/onprem/inventory.env` à partir de `inventories/onprem/lab.env.example` ;
   - sourcer cet inventaire ;
   - vérifier son contenu via `scripts/shared/render-inventory.sh` si besoin.

3. **Préparation système des nœuds**
   - exécuter `scripts/onprem/prepare-hosts.sh` pour préparer `server`, `node-0`, `node-1`.

4. **Exécution du socle Kubernetes**
   - suivre les étapes documentées dans `docs/core/` ;
   - utiliser les scripts mutualisés de `scripts/shared/` en appui.

5. **Validation**
   - exécuter les validations décrites dans `docs/core/09-smoke-tests.md` ;
   - utiliser `scripts/shared/smoke-tests.sh` pour la partie actuellement automatisée.

6. **Conservation des preuves**
   - stocker les sorties utiles dans `evidence/` selon la discipline opératoire retenue.

### 12.1. Point d’attention

Le flux on-prem ne doit pas être décrit comme une exécution séquentielle d’une suite `01-*` à `11-*` dans `scripts/core/`, ni comme un scénario Terraform on-prem déjà présent dans le dépôt, car ce n’est pas le cas dans l’état actuel du repository.

---

## 13. Flux de Cleanup

Le nettoyage on-prem repose sur le script réel `scripts/onprem/cleanup.sh`.

### 13.1. Séquence visible

Le script effectue :

1. une confirmation interactive ;
2. un nettoyage via `virsh` si `virsh` est disponible ;
3. la destruction des VMs `jumpbox`, `server`, `node-0`, `node-1` ;
4. la suppression du réseau `k8s-thw-net` ;
5. la suppression locale de `inventories/onprem/inventory.env`.

### 13.2. Comportement en absence de `virsh`

Si `virsh` n’est pas disponible, le script avertit l’utilisateur et le nettoyage de l’hyperviseur reste manuel.

### 13.3. Vérifications recommandées

Après cleanup, il est recommandé de vérifier :

- l’absence de VMs locales résiduelles ;
- l’absence du réseau local virtuel concerné ;
- l’absence d’inventaire local résiduel.

---

## 14. Risques Spécifiques

| Risque | Impact | Probabilité | Mitigation |
| :--- | :--- | :--- | :--- |
| Ressources insuffisantes | VMs lentes ou instables | Moyen | Vérifier la capacité de l’hôte avant déploiement |
| Conflit réseau | Collision d’adresses IP | Faible | Utiliser un CIDR dédié non utilisé localement |
| Hyperviseur incompatible | Échec partiel du lab | Moyen | Tester l’environnement local avant bootstrap |
| Accès Internet limité | Téléchargements impossibles | Moyen | Pré-télécharger les binaires et images nécessaires |
| Inventaire incomplet | Blocage du socle | Moyen | Vérifier `inventory.env` avant préparation des nœuds |

---

## 15. Points d'Attention

- **Performances :** Les performances dépendent directement des ressources de l’hôte local.
- **IP Forwarding :** `scripts/onprem/prepare-hosts.sh` active `net.ipv4.ip_forward=1` sur `server`, `node-0`, `node-1`.
- **Modules noyau :** Le script charge `overlay` et `br_netfilter`, indispensables au fonctionnement attendu du socle.
- **Virtualisation locale :** Le comportement réseau et la stabilité peuvent varier selon `virsh`, VirtualBox, VMware ou autre hyperviseur local.
- **Air-gapped :** Le mode on-prem reste le plus adapté aux laboratoires déconnectés, sous réserve de préparer les artefacts nécessaires.

---

## 16. Limites Connues de la V1

- pas de haute disponibilité control plane ;
- pas de load balancer externe standardisé ;
- pas de stockage distribué partagé visible dans le dépôt ;
- performances dépendantes de l’hôte local ;
- configuration réseau moins standardisée que sur les providers cloud ;
- pas de centralisation visible des logs ni du monitoring ;
- la création initiale des VMs et du réseau local reste hors du périmètre automatisé du dépôt.

---

## 17. Conclusion

Le provider on-prem apporte une valeur forte au dépôt, car il montre comment conserver la même logique d’architecture Kubernetes tout en sortant du paradigme cloud public.

Son rôle dans la V1 actuelle est clair :

- structurer un environnement local cohérent avec le socle commun ;
- formaliser le contrat d’inventaire ;
- assister la préparation système et le cleanup ;
- laisser la création initiale des VMs à l’environnement local de l’utilisateur.

---

## 18. Signature

**Auteur :** Zidane Djamal  
**Rôle :** Architecte technique senior

