# Provider Overlay : Microsoft Azure

**Auteur :** Zidane Djamal

## Le rôle de l'overlay
L'overlay Azure est chargé de provisionner les ressources IaaS sur le cloud Microsoft. Il crée le Resource Group, le Virtual Network (VNet), et les Virtual Machines (VMs) qui hébergeront le cluster Kubernetes. Son rôle s'achève par la génération du fichier d'inventaire `inventory.env` utilisé par le socle Core.

## Ce qui change pour ce provider
Azure a une approche très granulaire de ses ressources réseau. Une VM n'a pas d'IP publique ou privée intrinsèque ; elle est attachée à une Network Interface (NIC), qui elle-même est attachée à une Public IP et à un Subnet. Le code Terraform est donc plus verbeux que sur d'autres clouds. 

Pour le routage du Pod CIDR, deux éléments sont cruciaux sur Azure :
1. **IP Forwarding :** Il doit être activé au niveau de la ressource *Network Interface* (NIC) des workers (`enable_ip_forwarding = true`), et non sur la VM elle-même.
2. **User Defined Routes (UDR) :** Une Route Table doit être créée, associée au Subnet, avec des routes pointant vers les IP privées des workers (type de next hop : `VirtualAppliance`).

## Prérequis spécifiques
- Un abonnement Azure actif.
- L'outil en ligne de commande `az` CLI installé et authentifié (`az login`).
- Les droits `Contributor` sur l'abonnement pour créer un Resource Group et ses ressources.
- Terraform (version 1.5.0 ou supérieure) installé.
- Une paire de clés SSH générée localement.

## Ordre de lecture recommandé
1. `docs/lld/azure.md` (Low Level Design) : Pour comprendre l'architecture réseau et compute spécifique à Azure.
2. Ce `README.md` : Pour comprendre l'utilisation de l'overlay.
3. Les fichiers Terraform dans `terraform/azure/`.

## Fichiers concernés
L'ensemble du code d'infrastructure se trouve dans le répertoire `terraform/azure/` :
- `main.tf` : Configuration du provider `azurerm` et création du Resource Group.
- `network.tf` : Création du VNet, Subnet, Network Security Group (NSG), Route Table et UDRs.
- `compute.tf` : Création des Public IPs, Network Interfaces (NICs) et Virtual Machines.
- `inventory.tf` : Génération du fichier `inventory.env`.

## Logique d'exécution
1. Se positionner dans le répertoire `terraform/azure/`.
2. Copier le fichier d'exemple : `cp terraform.tfvars.example terraform.tfvars`.
3. Éditer `terraform.tfvars` si nécessaire (la région par défaut est `westeurope`).
4. Initialiser Terraform : `terraform init`.
5. Vérifier le plan d'exécution : `terraform plan`.
6. Appliquer la configuration : `terraform apply -auto-approve`.
7. Vérifier que le fichier `inventories/azure/inventory.env` a bien été généré.

## Variables clés
- `location` : La région Azure de déploiement (par défaut `westeurope`).
- `resource_group_name` : Le nom du groupe de ressources (par défaut `k8s-thw-rg`).
- `vm_size` : La taille des VMs (par défaut `Standard_B2s`).
- `ssh_public_key_path` : Le chemin vers votre clé publique SSH.

## Points de vigilance
- **Coûts :** Les VMs et les adresses IP publiques Standard SKU génèrent des coûts. La suppression du Resource Group via `terraform destroy` supprime proprement toutes les ressources associées.
- **Délai de provisionnement :** La création de VMs sur Azure peut être légèrement plus longue que sur d'autres clouds (comptez 2 à 3 minutes).
- **Nommage :** Azure impose certaines restrictions sur la longueur et les caractères des noms de ressources (ex: pas de majuscules pour les noms de compte de stockage si utilisés). Le code Terraform gère ces conventions.

## Limites de l'overlay (V1)
- Déploiement dans une seule région et zone.
- Les VMs disposent d'adresses IP publiques directes.
- Pas d'utilisation de Managed Identity pour les VMs.
- Pas d'intégration avec Azure Key Vault.
