# Provider Overlay : IBM Cloud

**Auteur :** Zidane Djamal

## Le rôle de l'overlay
L'overlay IBM Cloud provisionne l'infrastructure IaaS (VPC Gen2, Virtual Servers, Floating IPs) nécessaire au déploiement du cluster Kubernetes. Son exécution permet de préparer un environnement conforme aux attentes des scripts Core, matérialisé par la génération du fichier `inventory.env`.

## Ce qui change pour ce provider
IBM Cloud VPC possède quelques particularités par rapport aux autres fournisseurs :
1. **IP Spoofing :** Pour que les workers puissent router le trafic des pods (dont les IP sources ne correspondent pas à l'IP de la carte réseau de la VM), il est obligatoire d'activer l'option `allow_ip_spoofing = true` sur les interfaces réseau des instances.
2. **Floating IPs :** Les adresses IP publiques sur IBM Cloud sont appelées "Floating IPs" et sont des ressources distinctes qui doivent être explicitement attachées aux interfaces réseau.
3. **Utilisateur SSH par défaut :** Contrairement à AWS, GCP ou Azure où l'utilisateur est souvent `ubuntu`, sur les images Ubuntu minimales d'IBM Cloud, l'utilisateur par défaut est `root`. L'inventaire généré reflète cette différence (`SSH_USER="root"`).

## Prérequis spécifiques
- Un compte IBM Cloud de type "Pay-As-You-Go" ou "Subscription" (les comptes "Lite" ne permettent pas de créer des VPC).
- L'outil en ligne de commande `ibmcloud` CLI installé et authentifié (`ibmcloud login`).
- Le plugin VPC installé : `ibmcloud plugin install vpc-infrastructure`.
- Une clé API IBM Cloud générée pour Terraform.
- Terraform (version 1.5.0 ou supérieure) installé.
- Une clé SSH enregistrée dans l'interface IBM Cloud VPC.

## Ordre de lecture recommandé
1. `docs/lld/ibmcloud.md` (Low Level Design) : Pour comprendre l'architecture réseau et compute spécifique à IBM Cloud.
2. Ce `README.md` : Pour comprendre l'utilisation de l'overlay.
3. Les fichiers Terraform dans `terraform/ibmcloud/`.

## Fichiers concernés
L'ensemble du code d'infrastructure se trouve dans le répertoire `terraform/ibmcloud/` :
- `main.tf` : Configuration du provider `ibm`.
- `network.tf` : Création du VPC, Subnet, Public Gateway, Security Group et Custom Routes.
- `compute.tf` : Création des Virtual Server Instances (jumpbox, server, node-0, node-1).
- `floating_ips.tf` : Allocation et attachement des Floating IPs.
- `inventory.tf` : Génération du fichier `inventory.env`.

## Logique d'exécution
1. Se positionner dans le répertoire `terraform/ibmcloud/`.
2. Copier le fichier d'exemple : `cp terraform.tfvars.example terraform.tfvars`.
3. Éditer `terraform.tfvars` pour y renseigner votre `ibmcloud_api_key` et le nom de votre clé SSH (`ssh_key_name`).
4. Initialiser Terraform : `terraform init`.
5. Vérifier le plan d'exécution : `terraform plan`.
6. Appliquer la configuration : `terraform apply -auto-approve`.
7. Vérifier que le fichier `inventories/ibmcloud/inventory.env` a bien été généré.

## Variables clés
- `ibmcloud_api_key` : Votre clé API (ne jamais commiter ce fichier).
- `region` : La région de déploiement (par défaut `eu-de` / Francfort).
- `zone` : La zone cible (par défaut `eu-de-1`).
- `profile` : Le profil de calcul des instances (par défaut `bx2-2x8`).
- `ssh_key_name` : Le nom exact de la clé SSH telle qu'enregistrée dans IBM Cloud VPC.

## Points de vigilance
- **Clé API :** Gérez votre clé API de manière sécurisée (utilisez une variable d'environnement `TF_VAR_ibmcloud_api_key` ou un fichier `.tfvars` ignoré par Git).
- **Floating IPs orphelines :** Assurez-vous que le `terraform destroy` supprime bien les Floating IPs. Une Floating IP non attachée à une instance continue d'être facturée.
- **Images OS :** L'ID de l'image Ubuntu peut changer. Le code Terraform utilise un data source pour récupérer la dernière version de l'image `ibm-ubuntu-22-04-4-minimal-amd64-1`.

## Limites de l'overlay (V1)
- Déploiement mono-zone.
- Les instances sont directement exposées via des Floating IPs.
- Pas d'utilisation de Trusted Profiles pour l'authentification des instances auprès des services IBM Cloud.
