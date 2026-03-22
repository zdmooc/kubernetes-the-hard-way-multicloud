# Provider Overlay : Amazon Web Services (AWS)

**Auteur :** Zidane Djamal

## Le rôle de l'overlay
L'overlay AWS a pour responsabilité exclusive de provisionner l'infrastructure sous-jacente sur le cloud Amazon. Il gère la création du réseau virtuel (VPC) et des instances de calcul (EC2) nécessaires au déploiement de Kubernetes. Son objectif final est de générer le fichier `inventory.env` qui servira de point d'entrée aux scripts d'installation du Core.

## Ce qui change pour ce provider
AWS utilise le concept de "Source/Destination Check" sur ses interfaces réseau élastiques (ENI). Par défaut, une instance EC2 rejette tout paquet réseau dont elle n'est pas la source ou la destination finale. Pour que le routage des pods fonctionne (le trafic entre les workers), il est impératif de désactiver ce contrôle sur les instances workers via l'attribut `source_dest_check = false`. De plus, le routage inter-nœuds nécessite la configuration de la Route Table du VPC.

## Prérequis spécifiques
- Un compte AWS actif.
- L'outil en ligne de commande `aws` CLI installé et configuré (`aws configure` avec Access Key et Secret Key).
- Les droits IAM nécessaires pour créer des VPC, EC2, et Security Groups.
- Terraform (version 1.5.0 ou supérieure) installé.
- Une paire de clés SSH générée localement.

## Ordre de lecture recommandé
1. `docs/lld/aws.md` (Low Level Design) : Pour comprendre l'architecture réseau et compute spécifique à AWS.
2. Ce `README.md` : Pour comprendre l'utilisation de l'overlay.
3. Les fichiers Terraform dans `terraform/aws/`.

## Fichiers concernés
L'ensemble du code d'infrastructure se trouve dans le répertoire `terraform/aws/` :
- `main.tf` : Configuration du provider `aws`.
- `network.tf` : Création du VPC, Subnet, Internet Gateway, Route Table et Security Group.
- `compute.tf` : Création des instances EC2 (jumpbox, server, node-0, node-1) et de la Key Pair.
- `routes.tf` : Configuration des routes pour le Pod CIDR.
- `inventory.tf` : Génération du fichier `inventory.env`.

## Logique d'exécution
1. Se positionner dans le répertoire `terraform/aws/`.
2. Copier le fichier d'exemple : `cp terraform.tfvars.example terraform.tfvars`.
3. Éditer `terraform.tfvars` si nécessaire (la région par défaut est `eu-west-1`).
4. Initialiser Terraform : `terraform init`.
5. Vérifier le plan d'exécution : `terraform plan`.
6. Appliquer la configuration : `terraform apply -auto-approve`.
7. Vérifier que le fichier `inventories/aws/inventory.env` a bien été généré.

## Variables clés
- `aws_region` : La région AWS de déploiement (par défaut `eu-west-1`).
- `aws_az` : L'Availability Zone cible (par défaut `eu-west-1a`).
- `instance_type_server` / `instance_type_worker` : Types d'instances EC2 (par défaut `t3.medium`).
- `ssh_public_key_path` : Le chemin vers votre clé publique SSH.

## Points de vigilance
- **Coûts :** Les instances `t3.medium` et les volumes EBS génèrent des coûts. N'oubliez pas d'exécuter `terraform destroy` après vos tests.
- **Elastic IPs :** Si l'overlay utilise des Elastic IPs pour l'accès public, assurez-vous qu'elles sont bien libérées lors du `destroy` pour éviter des frais résiduels.
- **Key Pair :** La clé publique SSH est importée dans AWS via Terraform. Assurez-vous que le chemin fourni dans les variables est correct, sinon l'accès SSH à la jumpbox sera impossible.

## Limites de l'overlay (V1)
- L'infrastructure est déployée dans une seule Availability Zone (Single-AZ).
- Pas de NAT Gateway : les instances sont déployées dans un sous-réseau public et possèdent des adresses IP publiques directes.
- Pas d'Instance Profile IAM : les instances EC2 n'ont pas de rôle IAM associé, elles ne peuvent donc pas interagir avec l'API AWS de l'intérieur.
