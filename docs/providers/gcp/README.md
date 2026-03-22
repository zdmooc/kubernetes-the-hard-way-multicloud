# Provider Overlay : Google Cloud Platform (GCP)

**Auteur :** Zidane Djamal

## Le rôle de l'overlay
L'overlay GCP a pour responsabilité exclusive de provisionner l'infrastructure sous-jacente sur Google Cloud Platform. Il agit comme la couche IaaS (Infrastructure as a Service) qui prépare le terrain pour l'installation de Kubernetes. Son objectif final et unique est de fournir des machines virtuelles accessibles, un réseau configuré, et de générer le contrat d'interface : le fichier `inventory.env`.

## Ce qui change pour ce provider
GCP se distingue par sa gestion native du routage avancé au niveau du VPC. Contrairement à d'autres clouds, GCP nécessite la création explicite de "Routes" pour que le trafic du Pod CIDR (le réseau interne des conteneurs) puisse circuler entre les instances Compute Engine. De plus, les instances nécessitent l'activation du paramètre `can_ip_forward = true` pour autoriser ce trafic.

## Prérequis spécifiques
- Un compte Google Cloud avec la facturation activée.
- Un projet GCP existant.
- L'outil en ligne de commande `gcloud` installé et authentifié (`gcloud auth application-default login`).
- Terraform (version 1.5.0 ou supérieure) installé.
- Une paire de clés SSH générée localement (ex: `~/.ssh/id_ed25519`).

## Ordre de lecture recommandé
1. `docs/lld/gcp.md` (Low Level Design) : Pour comprendre l'architecture réseau et compute spécifique à GCP.
2. Ce `README.md` : Pour comprendre l'utilisation de l'overlay.
3. Les fichiers Terraform dans `terraform/gcp/` : Pour inspecter le code d'infrastructure.

## Fichiers concernés
L'ensemble du code d'infrastructure se trouve dans le répertoire `terraform/gcp/` :
- `main.tf` : Configuration du provider `google`.
- `network.tf` : Création du VPC, Subnet, Firewall Rules et Routes.
- `compute.tf` : Création des instances (jumpbox, server, node-0, node-1).
- `inventory.tf` : Génération du fichier `inventory.env` à partir du template.
- `variables.tf` / `outputs.tf` : Définition des entrées/sorties.

## Logique d'exécution
1. Se positionner dans le répertoire `terraform/gcp/`.
2. Copier le fichier d'exemple : `cp terraform.tfvars.example terraform.tfvars`.
3. Éditer `terraform.tfvars` pour y renseigner obligatoirement le `project_id`.
4. Initialiser Terraform : `terraform init`.
5. Vérifier le plan d'exécution : `terraform plan`.
6. Appliquer la configuration : `terraform apply -auto-approve`.
7. Vérifier que le fichier `inventories/gcp/inventory.env` a bien été généré à la racine du projet.

## Variables clés
- `project_id` : L'identifiant unique de votre projet GCP (obligatoire).
- `region` / `zone` : La localisation des ressources (par défaut `europe-west1` / `europe-west1-b`).
- `machine_type` : Le type d'instance (par défaut `e2-standard-2`).
- `ssh_public_key_path` : Le chemin vers votre clé publique SSH (par défaut `~/.ssh/id_ed25519.pub`).

## Points de vigilance
- **Coûts :** L'infrastructure provisionnée (4 instances `e2-standard-2`) engendre des coûts horaires. Pensez systématiquement à exécuter `terraform destroy` après vos sessions de laboratoire.
- **Quotas :** Assurez-vous que votre projet GCP dispose de suffisamment de quotas pour les CPU et les adresses IP publiques dans la région choisie.
- **Firewall :** La règle de pare-feu externe ouvre le port 6443 (API Kubernetes) à `0.0.0.0/0`. Pour un laboratoire temporaire, c'est acceptable, mais en environnement persistant, restreignez cette règle à votre adresse IP publique.

## Limites de l'overlay (V1)
- L'infrastructure est déployée dans une seule zone (Single-AZ), ce qui ne garantit pas la haute disponibilité face à une panne zonale.
- Les instances disposent d'adresses IP publiques directes. Une architecture de production utiliserait Cloud NAT pour masquer les workers.
- Le routage du Pod CIDR repose sur des routes statiques VPC, ce qui n'est pas scalable pour un cluster de grande taille (nécessiterait un CNI avancé comme Calico en mode BGP).
