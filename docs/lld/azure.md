# Low Level Design (LLD) Provider : Microsoft Azure

**Version :** 1.0.0
**Auteur :** Zidane Djamal, Architecte technique senior

---

## 1. Présentation du Provider

Microsoft Azure est le deuxième fournisseur Cloud mondial en termes de parts de marché. Son adoption est particulièrement forte dans les entreprises ayant un écosystème Microsoft existant (Active Directory, Office 365, Windows Server). Dans le cadre de ce projet, Azure est utilisé pour démontrer le déploiement de Kubernetes sur des Virtual Machines Azure au sein d'un Virtual Network (VNet) dédié.

L'infrastructure sera provisionnée via Terraform en utilisant le provider `azurerm`. L'ensemble des ressources sera créé dans un Resource Group dédié, au sein d'une seule région et d'une seule zone de disponibilité.

---

## 2. Hypothèses Spécifiques

- L'utilisateur dispose d'un abonnement Azure actif avec les droits Contributor sur le Resource Group cible.
- L'Azure CLI (`az`) est installée et configurée localement (`az login`).
- Le déploiement cible une seule région (ex: `westeurope`) pour minimiser les coûts.
- Les VMs utilisent l'image Ubuntu 22.04 LTS de Canonical (offre `0001-com-ubuntu-server-jammy`).
- L'accès SSH est géré via une clé publique injectée lors de la création des VMs.
- Le quota par défaut de l'abonnement Azure est suffisant pour 4 VMs `Standard_B2s`.

---

## 3. Architecture Réseau

### 3.1. Composants Réseau

| Ressource Azure | Nom | Description |
| :--- | :--- | :--- |
| **Resource Group** | `k8s-thw-rg` | Groupe de ressources contenant l'ensemble de l'infrastructure |
| **Virtual Network (VNet)** | `k8s-thw-vnet` | Réseau virtuel avec CIDR `10.240.0.0/16` |
| **Subnet** | `k8s-thw-subnet` | Sous-réseau unique `10.240.0.0/24` |
| **Network Security Group (NSG)** | `k8s-thw-nsg` | Groupe de sécurité réseau attaché au subnet |
| **Public IP** | `k8s-thw-<hostname>-pip` | Adresse IP publique par VM (Standard SKU) |
| **Route Table** | `k8s-thw-rt` | Table de routage pour les Pod CIDRs |

### 3.2. Plan d'Adressage

| Bloc CIDR | Usage |
| :--- | :--- |
| `10.240.0.0/16` | VNet CIDR |
| `10.240.0.0/24` | Subnet infrastructure (VMs) |
| `10.200.0.0/16` | Pod CIDR global |
| `10.200.0.0/24` | Pod CIDR node-0 |
| `10.200.1.0/24` | Pod CIDR node-1 |
| `10.32.0.0/24` | Service CIDR |

### 3.3. Routes pour le Pod CIDR (User Defined Routes)

Azure ne route pas nativement le trafic vers les Pod CIDRs. Des User Defined Routes (UDR) doivent être créées dans la Route Table et associées au subnet :

| Route | Destination | Next Hop Type | Next Hop Address |
| :--- | :--- | :--- | :--- |
| `route-node-0-pods` | `10.200.0.0/24` | VirtualAppliance | `10.240.0.20` |
| `route-node-1-pods` | `10.200.1.0/24` | VirtualAppliance | `10.240.0.21` |

**Important :** Le paramètre `enable_ip_forwarding = true` doit être activé sur les Network Interfaces des workers pour permettre le forwarding de paquets.

---

## 4. Architecture Compute

### 4.1. Instances

| Hostname | Taille VM | vCPU | RAM | Disque OS | IP Privée | IP Publique |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `jumpbox` | `Standard_B2s` | 2 | 4 Go | 30 Go Premium SSD | `10.240.0.10` | Statique |
| `server` | `Standard_B2s` | 2 | 4 Go | 50 Go Premium SSD | `10.240.0.11` | Statique |
| `node-0` | `Standard_B2s` | 2 | 4 Go | 50 Go Premium SSD | `10.240.0.20` | Statique |
| `node-1` | `Standard_B2s` | 2 | 4 Go | 50 Go Premium SSD | `10.240.0.21` | Statique |

### 4.2. Configuration des VMs

Chaque VM sera créée avec les paramètres suivants :

- **Image :** Canonical `0001-com-ubuntu-server-jammy` version `22.04-LTS`
- **OS Disk :** `Premium_LRS` (SSD)
- **Admin username :** `ubuntu`
- **Authentication :** Clé publique SSH uniquement (pas de mot de passe)
- **Network Interface :** IP privée statique, IP publique Standard SKU
- **enable_ip_forwarding :** `true` sur les NIC des workers et du server

### 4.3. Ressources Associées par VM

Chaque VM Azure nécessite la création explicite de plusieurs ressources associées :

| Ressource | Nom | Description |
| :--- | :--- | :--- |
| **Public IP** | `k8s-thw-<hostname>-pip` | IP publique Standard SKU, allocation statique |
| **Network Interface** | `k8s-thw-<hostname>-nic` | Interface réseau avec IP privée statique |
| **OS Disk** | (géré automatiquement) | Disque OS Premium SSD |

---

## 5. Sécurité

### 5.1. Network Security Group (`k8s-thw-nsg`)

**Règles Inbound :**

| Priorité | Nom | Protocole | Port(s) | Source | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 100 | `allow-ssh` | TCP | 22 | `*` | Accès SSH |
| 110 | `allow-api-server` | TCP | 6443 | `*` | API Kubernetes |
| 120 | `allow-internal` | `*` | `*` | `10.240.0.0/24` | Trafic interne cluster |
| 130 | `allow-pod-cidr` | `*` | `*` | `10.200.0.0/16` | Trafic Pod CIDR |
| 140 | `allow-icmp` | ICMP | `*` | `*` | Ping |

**Règles Outbound :** Règle par défaut Azure (tout le trafic sortant autorisé).

### 5.2. Principes de Sécurité V1

Pour la V1, il n'y a pas de Managed Identity dédiée aux VMs, pas de Azure Key Vault, pas de Private Endpoints, et pas de NACLs supplémentaires. Le périmètre de sécurité repose sur le NSG et l'authentification SSH par clé.

---

## 6. Accès SSH

L'accès SSH est configuré via l'injection de la clé publique lors de la création de chaque VM (paramètre `admin_ssh_key` dans le bloc `azurerm_linux_virtual_machine`). La `jumpbox` sert de bastion :

1. L'utilisateur se connecte à la `jumpbox` depuis son poste local :
   ```bash
   ssh -i ~/.ssh/id_ed25519 ubuntu@<JUMPBOX_PUBLIC_IP>
   ```
2. Depuis la `jumpbox`, l'utilisateur accède aux autres nœuds via SSH par IP privée :
   ```bash
   ssh ubuntu@10.240.0.11  # server
   ssh ubuntu@10.240.0.20  # node-0
   ssh ubuntu@10.240.0.21  # node-1
   ```

**Alternative Azure Bastion :** Azure propose un service Bastion managé, mais il est hors périmètre V1 (coût supplémentaire et complexité).

---

## 7. IP / DNS

### 7.1. Adresses IP

Les IP privées sont assignées statiquement via Terraform (paramètre `private_ip_address_allocation = "Static"` et `private_ip_address` dans le bloc `ip_configuration` de la NIC). Les IP publiques sont de type Standard SKU avec allocation statique, garantissant leur persistance au redémarrage.

### 7.2. Résolution DNS

Azure fournit un DNS interne au VNet. Cependant, pour garantir la cohérence avec les autres providers, le fichier `/etc/hosts` de chaque nœud sera enrichi par un script de préparation avec les correspondances hostname-IP.

---

## 8. Variables Attendues

### 8.1. Variables Terraform (`variables.tf`)

| Variable | Type | Valeur par défaut | Description |
| :--- | :--- | :--- | :--- |
| `resource_group_name` | `string` | `k8s-thw-rg` | Nom du Resource Group |
| `location` | `string` | `westeurope` | Région Azure |
| `vm_size` | `string` | `Standard_B2s` | Taille des VMs |
| `admin_username` | `string` | `ubuntu` | Nom d'utilisateur admin |
| `ssh_public_key_path` | `string` | `~/.ssh/id_ed25519.pub` | Chemin vers la clé publique SSH |

---

## 9. Structure Terraform Prévue

```text
terraform/azure/
├── main.tf                  # Provider azurerm, Resource Group
├── variables.tf             # Variables d'entrée
├── outputs.tf               # Sorties (IPs publiques, privées)
├── network.tf               # VNet, Subnet, NSG, Route Table, UDRs
├── compute.tf               # VMs (jumpbox, server, node-0, node-1)
├── inventory.tf             # Génération du fichier inventory.env
├── templates/
│   └── inventory.env.tpl    # Template pour l'inventory
├── terraform.tfvars.example # Exemple de fichier de variables
└── README.md                # Instructions spécifiques Azure
```

---

## 10. Structure Scripts Prévue

```text
scripts/providers/azure/
├── 00-validate-prerequisites.sh   # Vérifie az cli, terraform, ssh-keygen
├── 01-provision.sh                # Wrapper autour de terraform apply
├── 99-cleanup.sh                  # Wrapper autour de terraform destroy
└── README.md                      # Instructions d'utilisation
```

---

## 11. Exemple d'Inventory

```bash
# === Kubernetes The Hard Way - Azure Inventory ===
# Provider: Microsoft Azure
# Region: westeurope

PROVIDER="azure"
REGION="westeurope"
ZONE="westeurope"

JUMPBOX_PUBLIC_IP="20.82.xxx.xxx"
SERVER_PUBLIC_IP="20.82.xxx.xxx"
NODE_0_PUBLIC_IP="20.82.xxx.xxx"
NODE_1_PUBLIC_IP="20.82.xxx.xxx"

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

1. **Pré-requis :** Vérifier l'installation de `az` CLI, `terraform`, et l'authentification Azure (`az login`).
2. **Provisionnement :** Se placer dans `terraform/azure/`, copier `terraform.tfvars.example` en `terraform.tfvars`, puis exécuter :
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
3. **Vérification de l'inventory :** Vérifier que `inventories/azure/inventory.env` a été correctement généré.
4. **Connexion à la Jumpbox :** `ssh -i ~/.ssh/id_ed25519 ubuntu@<JUMPBOX_PUBLIC_IP>`
5. **Clonage du dépôt sur la Jumpbox :** `git clone https://github.com/zdmooc/kubernetes-the-hard-way-multicloud.git`
6. **Sourcing de l'inventory :** `source inventories/azure/inventory.env`
7. **Exécution séquentielle des scripts Core :** `01-prerequisites.sh` à `11-smoke-tests.sh`
8. **Collecte des preuves :** Les scripts génèrent automatiquement des fichiers dans `evidence/`.

---

## 13. Flux de Cleanup

1. **Nettoyage Kubernetes (optionnel) :** Suppression des ressources Kubernetes de test.
2. **Destruction de l'infrastructure :**
   ```bash
   cd terraform/azure/
   terraform destroy -auto-approve
   ```

**Alternative rapide :** Supprimer directement le Resource Group entier :
```bash
az group delete --name k8s-thw-rg --yes --no-wait
```

**Vérification post-cleanup :** Exécuter `az vm list --resource-group k8s-thw-rg -o table` pour confirmer la suppression.

---

## 14. Risques Spécifiques

| Risque | Impact | Probabilité | Mitigation |
| :--- | :--- | :--- | :--- |
| **Coûts VMs non maîtrisés** | Facturation inattendue | Moyen | Toujours exécuter `terraform destroy` ; configurer Azure Cost Management |
| **IP Forwarding oublié** | Trafic Pod bloqué | Élevé | Automatiser via Terraform (`enable_ip_forwarding = true`) |
| **NSG trop permissif** | Surface d'attaque élargie | Moyen | Restreindre les sources SSH à l'IP de l'administrateur en production |
| **Quotas régionaux** | Échec du provisionnement | Faible | Vérifier les quotas via `az vm list-usage --location westeurope` |

---

## 15. Points d'Attention

- **Facturation :** Les VMs `Standard_B2s` coûtent environ 0,042 USD/heure chacune en `westeurope`. Les IP publiques Standard SKU sont facturées même lorsque la VM est arrêtée (deallocated).
- **IP Forwarding :** C'est le point technique le plus critique sur Azure. Le paramètre `enable_ip_forwarding` doit être activé sur la Network Interface (pas sur la VM elle-même). Sans ce paramètre, le routage des pods entre workers échouera.
- **Nombre de ressources :** Azure nécessite la création explicite de plus de ressources que GCP ou AWS pour le même résultat (Public IP + NIC + VM sont des ressources séparées). Le code Terraform sera donc plus verbeux.
- **Resource Group :** Toutes les ressources sont contenues dans un seul Resource Group, ce qui simplifie le cleanup (suppression du RG = suppression de tout).

---

## 16. Limites Connues de la V1

- Déploiement mono-région (pas de résilience géographique).
- Pas de Load Balancer Azure devant l'API Server.
- Pas de NAT Gateway (les VMs ont des IP publiques directes).
- Pas de Managed Identity pour les VMs.
- Pas d'intégration avec Azure Key Vault pour le chiffrement des secrets etcd.
- Les UDR pour le Pod CIDR ne sont pas scalables au-delà de quelques nœuds.
- Pas d'Azure Bastion (accès SSH direct via IP publique).
- Pas de Proximity Placement Group (latence non optimisée entre VMs).

---
**Signé :**
*Zidane Djamal*
*Architecte technique senior*
