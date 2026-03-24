
# docs/lld/azure.md

# Low Level Design (LLD) Provider : Microsoft Azure

**Version :** 1.1.0  
**Auteur :** Zidane Djamal  
**Rôle :** Architecte technique senior

---

## 1. Présentation du Provider

Microsoft Azure constitue un provider important du dépôt `kubernetes-the-hard-way-multicloud`.

Son intérêt dans cette architecture multi-cloud est double :

- représenter un cas d’usage fréquent dans les environnements d’entreprise orientés Microsoft ;
- démontrer l’adaptation du socle Kubernetes « hard way » à un environnement de Virtual Machines Azure attachées à des NICs, Public IPs, un VNet et une Route Table.

Dans cette architecture, l’overlay Azure a une responsabilité claire :

- provisionner les ressources IaaS minimales ;
- créer le réseau, les routes et les interfaces nécessaires ;
- créer les VMs supportant le cluster ;
- générer `inventories/azure/inventory.env` lorsque le provider est exécuté avec succès.

Le provider Azure ne déploie pas Kubernetes lui-même. Il prépare l’environnement d’exécution du socle.

---

## 2. Hypothèses Spécifiques

- L’utilisateur dispose d’un abonnement Azure actif avec des droits suffisants pour créer un Resource Group, un VNet, un Subnet, un NSG, une Route Table, des Public IPs, des NICs et des VMs.
- Le CLI `az` est installé et authentifié localement.
- Le déploiement cible une seule région pour la V1, par défaut `westeurope`.
- Les VMs utilisent une image Ubuntu 22.04 LTS Canonical récupérée dans Terraform via `source_image_reference`.
- L’accès SSH repose sur une clé publique injectée dans les VMs via `admin_ssh_key`.
- Le dimensionnement exact dépend du code Terraform réel :
  - `jumpbox` est définie explicitement en `Standard_B1s` ;
  - `server`, `node-0` et `node-1` utilisent `var.vm_size` avec une valeur par défaut `Standard_B2s`.
- Le provider Azure est présent structurellement et techniquement exploitable en V1, avec génération d’un `inventory.env` visible dans le code Terraform.

---

## 3. Architecture Réseau

### 3.1. Composants Réseau

| Ressource Azure | Nom | Description |
| :--- | :--- | :--- |
| **Resource Group** | `k8s-thw-rg` | Groupe de ressources contenant l’ensemble de l’infrastructure |
| **Virtual Network (VNet)** | `k8s-thw-vnet` | Réseau virtuel avec CIDR `10.240.0.0/24` |
| **Subnet** | `k8s-thw-subnet` | Sous-réseau unique `10.240.0.0/24` |
| **Network Security Group (NSG)** | `k8s-thw-nsg` | Groupe de sécurité réseau associé au subnet |
| **Route Table** | `k8s-thw-rt` | Table de routage contenant les UDR pour les Pod CIDRs |
| **Subnet Route Table Association** | `k8s_rta` | Association entre le subnet et la route table |
| **Public IP** | `<hostname>-pip` | Adresse IP publique statique par VM |

### 3.2. Plan d'Adressage

| Bloc CIDR | Usage |
| :--- | :--- |
| `10.240.0.0/24` | Réseau infrastructure (VNet et subnet) |
| `10.200.0.0/16` | Pod CIDR global |
| `10.200.0.0/24` | Pod CIDR node-0 |
| `10.200.1.0/24` | Pod CIDR node-1 |
| `10.32.0.0/24` | Service CIDR |

### 3.3. Routes pour le Pod CIDR (User Defined Routes)

Azure ne route pas nativement le trafic du Pod CIDR dans cette architecture V1. Des UDR explicites sont créées dans la route table :

| Route | Destination | Next Hop Type | Next Hop Address |
| :--- | :--- | :--- | :--- |
| `route-node-0` | `10.200.0.0/24` | `VirtualAppliance` | `10.240.0.20` |
| `route-node-1` | `10.200.1.0/24` | `VirtualAppliance` | `10.240.0.21` |

### 3.4. Point d’Attention Réseau

Le routage Pod-to-Pod dépend de deux éléments visibles dans l’implémentation Azure :

- `enable_ip_forwarding = true` sur les NIC des workers ;
- la route table avec UDR pointant vers les workers.

Sans ces deux mécanismes, le trafic inter-pods entre nœuds ne fonctionne pas correctement.

---

## 4. Architecture Compute

### 4.1. Instances

| Hostname | Taille VM | Disque OS | IP Privée | IP Publique |
| :--- | :--- | :--- | :--- | :--- |
| `jumpbox` | `Standard_B1s` | 30 Go `Premium_LRS` | `10.240.0.10` | Statique |
| `server` | `var.vm_size` | 50 Go `Premium_LRS` | `10.240.0.11` | Statique |
| `node-0` | `var.vm_size` | 50 Go `Premium_LRS` | `10.240.0.20` | Statique |
| `node-1` | `var.vm_size` | 50 Go `Premium_LRS` | `10.240.0.21` | Statique |

### 4.2. Configuration observée dans le code Terraform

Les éléments visibles dans `terraform/azure/main.tf` sont les suivants :

- `jumpbox` fixée à `Standard_B1s` ;
- `server`, `node-0`, `node-1` pilotés par `var.vm_size` ;
- IP privées statiques portées par les NICs ;
- IP publiques statiques Standard SKU ;
- image Canonical Ubuntu 22.04 LTS ;
- `admin_ssh_key` injectée pour l’utilisateur `ssh_user` ;
- `enable_ip_forwarding = true` sur les NIC des workers ;
- Resource Group, VNet, subnet, route table, NSG, Public IPs, NICs et VMs créés explicitement.

### 4.3. Ressources associées

Azure matérialise plusieurs ressources par machine :

| Ressource | Description |
| :--- | :--- |
| Public IP | IP publique statique Standard SKU |
| Network Interface | NIC avec IP privée statique |
| Linux Virtual Machine | VM attachée à la NIC |
| OS Disk | Disque OS géré via la VM |

### 4.4. Interprétation d’architecture

Cette implémentation confirme une architecture V1 :

- lisible mais plus verbeuse que GCP ou AWS ;
- déterministe sur les IP privées ;
- adaptée à un laboratoire mono-région ;
- cohérente avec la granularité native d’Azure.

---

## 5. Sécurité

### 5.1. Network Security Group (`k8s-thw-nsg`)

Le NSG visible dans `terraform/azure/main.tf` est volontairement simple.

**Règles Inbound visibles :**

| Priorité | Nom | Protocole | Port(s) | Source | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1001 | `Allow-SSH` | TCP | `22` | `*` | Accès SSH |
| 1002 | `Allow-KubeAPI` | TCP | `6443` | `*` | API Kubernetes |
| 1003 | `Allow-Internal` | `*` | `*` | `10.240.0.0/24`, `10.200.0.0/16` | Trafic interne cluster et Pod CIDR |

Les règles Outbound reposent sur le comportement Azure par défaut autorisant le trafic sortant.

### 5.2. Principes de Sécurité V1

Pour la V1, la sécurité reste volontairement simple :

- un NSG unique ;
- pas de Managed Identity visible ;
- pas de Key Vault ;
- pas de Private Endpoint ;
- authentification SSH par clé.

### 5.3. Point d’attention documentaire

Le LLD Azure ne doit pas décrire des règles réseau plus fines que celles réellement visibles dans `main.tf`. Le NSG actuellement implémenté est plus simple que la cible sécurité qu’on pourrait attendre en environnement durable.

---

## 6. Accès SSH

L’accès SSH est géré par injection de la clé publique dans chaque VM via `admin_ssh_key`.

### 6.1. Principes

- l’utilisateur fournit une clé publique via `ssh_public_key_path` ;
- Terraform injecte cette clé dans chaque VM Azure ;
- l’utilisateur SSH par défaut est `ubuntu` via `ssh_user` ;
- la jumpbox joue le rôle de point d’entrée privilégié pour les opérations du socle.

### 6.2. Accès opératoire

`outputs.tf` fournit une commande SSH de référence vers la jumpbox, construite à partir de :

- `ssh_user` ;
- `ssh_public_key_path` transformé en chemin de clé privée ;
- l’IP publique de la jumpbox.

### 6.3. Point d’attention

Azure Bastion peut constituer une alternative, mais il n’est pas visible dans l’implémentation V1 actuelle et reste hors périmètre du dépôt dans son état présent.

---

## 7. IP / DNS

### 7.1. Adresses IP

Les IP privées sont portées par les NICs avec allocation statique.

Les IP publiques sont de type Standard SKU avec allocation statique, ce qui garantit leur stabilité sur la durée du laboratoire.

### 7.2. Résolution DNS

Azure fournit un DNS interne au VNet. Le LLD Azure ne doit pas affirmer qu’un enrichissement automatique de `/etc/hosts` existe déjà dans le provider si cela n’est pas visible dans les scripts présents. Cette préparation peut relever d’une étape manuelle ou du socle selon le niveau de maturité du dépôt.

### 7.3. Valeur de zone dans l’inventaire

Dans l’inventaire généré par Terraform pour Azure, la variable `ZONE` est aujourd’hui fixée à `none`. Le LLD doit s’aligner sur cette réalité, et non présenter `ZONE="westeurope"`.

---

## 8. Variables Attendues

### 8.1. Variables Terraform (`variables.tf`)

| Variable | Type | Valeur par défaut | Description |
| :--- | :--- | :--- | :--- |
| `location` | `string` | `westeurope` | Région Azure |
| `resource_group_name` | `string` | `k8s-thw-rg` | Nom du Resource Group |
| `vm_size` | `string` | `Standard_B2s` | Taille des VMs `server` et workers |
| `ssh_public_key_path` | `string` | `~/.ssh/id_ed25519.pub` | Chemin vers la clé publique SSH |
| `ssh_user` | `string` | `ubuntu` | Utilisateur SSH |
| `pod_cidr` | `string` | `10.200.0.0/16` | Pod CIDR global |
| `service_cidr` | `string` | `10.32.0.0/24` | Service CIDR |
| `cluster_dns` | `string` | `10.32.0.10` | IP du DNS cluster |

### 8.2. Variables d’inventaire

Le fichier `inventories/azure/inventory.env`, lorsqu’il est généré, porte notamment :

- les IP publiques et privées ;
- les CIDR Kubernetes ;
- les versions de référence ;
- les paramètres d’accès SSH.

### 8.3. `lab.env.example` vs `inventory.env`

Le provider Azure suit la distinction standard du dépôt :

- `inventories/azure/lab.env.example` : exemple versionné ;
- `inventories/azure/inventory.env` : fichier d’exécution généré localement par Terraform quand le provider est exécuté.

---

## 9. Structure Terraform Réelle

```text
terraform/azure/
├── inventory.tpl
├── main.tf
├── outputs.tf
├── variables.tf
└── versions.tf
```

### 9.1. Rôle des fichiers

- `main.tf` : Resource Group, réseau, NSG, Public IPs, NICs, VMs, routes et génération de l’inventaire ;
- `variables.tf` : variables d’entrée ;
- `outputs.tf` : IP publiques et commande SSH ;
- `versions.tf` : contraintes Terraform et providers ;
- `inventory.tpl` : template utilisé pour générer `inventories/azure/inventory.env`.

### 9.2. Point d’attention documentaire

Le dépôt réel ne montre pas, à ce stade :

- `network.tf` ;
- `compute.tf` ;
- `inventory.tf` ;
- `templates/` ;
- `terraform.tfvars.example`.

Le LLD Azure doit donc décrire la structure réellement présente, et non une structure cible théorique.

---

## 10. Structure Scripts Réelle

```text
scripts/azure/
├── cleanup.sh
└── provision.sh
```

### 10.1. Rôle des scripts provider

Les scripts Azure sont des wrappers légers autour de Terraform :

- `provision.sh` : exécute le provisioning depuis `terraform/azure/` ;
- `cleanup.sh` : exécute la destruction Terraform puis supprime `inventories/azure/inventory.env`.

### 10.2. Limite actuelle à expliciter

Le script `provision.sh` référence encore un fichier `terraform.tfvars` et mentionne `terraform.tfvars.example`, alors que ce dernier n’est pas visible dans le dépôt actuel. Cet écart doit être documenté comme une dette de stabilisation V1.

### 10.3. Relation avec le socle

Ces scripts ne déploient pas Kubernetes. Ils préparent uniquement l’infrastructure et le contrat d’interface attendu par le socle (`inventory.env`).

---

## 11. Exemple d'Inventory

```bash
PROVIDER="azure"
REGION="westeurope"
ZONE="none"

JUMPBOX_PUBLIC_IP="20.x.x.x"
SERVER_PUBLIC_IP="20.x.x.x"
NODE_0_PUBLIC_IP="20.x.x.x"
NODE_1_PUBLIC_IP="20.x.x.x"

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
- `inventories/azure/lab.env.example` ;
- la baseline technique V1 du dépôt.

---

## 12. Flux d'Exécution

Le flux de déploiement Azure V1 peut être résumé ainsi :

1. **Préparation locale**
   - vérifier `az`, `terraform`, la clé SSH et les prérequis système ;
   - vérifier l’authentification Azure.

2. **Provisionnement Azure**
   - exécuter Terraform dans `terraform/azure/` ou utiliser `scripts/azure/provision.sh` ;
   - fournir les variables nécessaires selon le contexte.

3. **Génération de l’inventaire**
   - vérifier la présence de `inventories/azure/inventory.env` ;
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

Le flux Azure ne doit pas être décrit comme une exécution séquentielle d’une suite `01-*` à `11-*` dans `scripts/core/`, car cette structure n’existe pas dans le dépôt réel.

---

## 13. Flux de Cleanup

Le nettoyage Azure repose sur le wrapper réel `scripts/azure/cleanup.sh` ou, à défaut, sur `terraform destroy` exécuté dans `terraform/azure/`.

### 13.1. Séquence visible

Le script réel effectue :

1. un positionnement dans `terraform/azure/` ;
2. une demande de confirmation interactive ;
3. un `terraform destroy -auto-approve` ;
4. une suppression locale de `inventories/azure/inventory.env`.

### 13.2. Vérifications recommandées

Après cleanup, il est recommandé de vérifier :

- l’absence de VMs résiduelles ;
- l’absence d’inventaire local résiduel ;
- la cohérence des ressources réseau supprimées.

### 13.3. Point d’attention

La suppression directe du Resource Group via `az group delete` peut constituer un raccourci opératoire, mais ce n’est pas le mécanisme principal implémenté dans le wrapper du dépôt. Le LLD doit donc d’abord décrire le flux réellement visible dans `scripts/azure/cleanup.sh`.

---

## 14. Risques Spécifiques

| Risque | Impact | Probabilité | Mitigation |
| :--- | :--- | :--- | :--- |
| Coûts VMs non maîtrisés | Facturation inattendue | Moyen | Toujours exécuter `terraform destroy` ; configurer Azure Cost Management |
| IP Forwarding oublié | Trafic Pod bloqué | Élevé | Automatiser via Terraform (`enable_ip_forwarding = true`) |
| NSG trop permissif | Surface d’attaque élargie | Moyen | Restreindre les sources SSH en environnement durable |
| Quotas régionaux | Échec du provisionnement | Faible | Vérifier les quotas avant déploiement |
| Inventaire incomplet | Blocage du socle | Moyen | Vérifier `inventory.env` avant bootstrap |

---

## 15. Points d'Attention

- **Facturation :** Le coût dépend notamment d’une `jumpbox` en `Standard_B1s`, de trois VMs pilotées par `vm_size` (par défaut `Standard_B2s`) et des IP publiques Standard SKU. Il est important de détruire l’infrastructure après les tests.
- **IP Forwarding :** C’est le point technique le plus critique sur Azure. Le paramètre `enable_ip_forwarding` doit être activé sur la Network Interface, pas sur la VM elle-même.
- **Nombre de ressources :** Azure nécessite la création explicite de plus de ressources que GCP ou AWS pour un résultat équivalent.
- **Resource Group :** Le regroupement de toutes les ressources dans un seul Resource Group simplifie fortement le cleanup.

---

## 16. Limites Connues de la V1

- déploiement mono-région ;
- pas de load balancer Azure devant l’API server ;
- pas de NAT Gateway ;
- pas de Managed Identity visible ;
- pas d’intégration Azure Key Vault pour le chiffrement etcd ;
- UDR peu scalables au-delà de quelques nœuds ;
- pas d’Azure Bastion ;
- pas de Proximity Placement Group.

---

## 17. Conclusion

Le provider Azure apporte une valeur forte au dépôt multi-cloud, car il rend visible une implémentation plus granulaire de l’infrastructure :

- Resource Group ;
- VNet ;
- subnet ;
- route table ;
- NSG ;
- Public IP ;
- NIC ;
- VM.

Le rôle du LLD Azure est donc double :

- documenter fidèlement cette granularité réelle ;
- servir de modèle de comparaison avec GCP et AWS.

---

## 18. Signature

**Auteur :** Zidane Djamal  
**Rôle :** Architecte technique senior



---
---