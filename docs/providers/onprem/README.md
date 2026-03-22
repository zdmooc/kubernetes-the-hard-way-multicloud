# Provider Overlay : On-Premises

**Auteur :** Zidane Djamal

## Le rôle de l'overlay
L'overlay On-Premises simule un environnement de centre de données local ou de serveur bare-metal. Son rôle est de provisionner des machines virtuelles locales (via un hyperviseur) qui hébergeront le cluster Kubernetes, sans dépendance à un fournisseur Cloud public. Cet environnement est idéal pour les expérimentations "air-gapped" ou pour éviter les coûts d'infrastructure Cloud.

## Ce qui change pour ce provider
Contrairement aux providers Cloud qui gèrent le réseau de manière logicielle (SDN), l'environnement On-Premises repose sur la configuration réseau du système d'exploitation hôte et de l'hyperviseur (bridge réseau, NAT). De plus, il n'y a pas de distinction entre IP publique et IP privée : les machines sont accédées directement via leurs adresses IP sur le réseau virtuel local.

Le routage du Pod CIDR entre les workers doit être géré manuellement en ajoutant des routes statiques dans la table de routage du système d'exploitation de chaque nœud.

## Prérequis spécifiques
- Une machine hôte (Linux, macOS ou Windows) avec au moins 16 Go de RAM et 4 cœurs CPU disponibles.
- Un hyperviseur installé :
  - **Scénario A (Recommandé) :** Linux avec `libvirt` / KVM.
  - **Scénario B :** VirtualBox (multi-plateforme).
- L'image ISO d'Ubuntu 22.04 LTS Server (pour VirtualBox) ou une image Cloud (qcow2) pour libvirt.
- Terraform (si utilisation de libvirt avec le provider `dmacvicar/libvirt`).

## Ordre de lecture recommandé
1. `docs/lld/onprem.md` (Low Level Design) : Pour comprendre l'architecture réseau et compute locale.
2. Ce `README.md` : Pour comprendre l'utilisation de l'overlay.
3. Les fichiers Terraform dans `terraform/onprem/` ou les scripts dans `scripts/providers/onprem/`.

## Fichiers concernés
**Si utilisation de libvirt (Terraform) :**
- `terraform/onprem/main.tf` : Configuration du provider `libvirt`.
- `terraform/onprem/network.tf` : Création du réseau virtuel.
- `terraform/onprem/compute.tf` : Création des domaines (VMs).
- `terraform/onprem/cloud_init.tf` : Configuration de l'injection SSH et IP statiques.

**Si utilisation de VirtualBox (Scripts) :**
- `scripts/providers/onprem/01-create-network.sh`
- `scripts/providers/onprem/02-create-vms.sh`

## Logique d'exécution (Scénario libvirt/Terraform)
1. Télécharger l'image Cloud Ubuntu 22.04 (`jammy-server-cloudimg-amd64.img`).
2. Se positionner dans le répertoire `terraform/onprem/`.
3. Copier le fichier d'exemple : `cp terraform.tfvars.example terraform.tfvars`.
4. Éditer `terraform.tfvars` pour indiquer le chemin local vers l'image téléchargée (`base_image_path`).
5. Initialiser Terraform : `terraform init`.
6. Appliquer la configuration : `terraform apply -auto-approve`.
7. Vérifier que le fichier `inventories/onprem/inventory.env` a bien été généré.

## Variables clés (libvirt)
- `libvirt_uri` : L'URI de connexion à l'hyperviseur (par défaut `qemu:///system`).
- `base_image_path` : Le chemin absolu vers l'image qcow2 Ubuntu.
- `ssh_public_key_path` : Le chemin vers votre clé publique SSH.
- `network_name` : Le nom du réseau libvirt (par défaut `k8s-thw-net`).

## Points de vigilance
- **Ressources matérielles :** Assurez-vous que votre machine hôte dispose d'assez de RAM. Le lancement de 4 VMs simultanées peut saturer un poste de travail modeste.
- **Routage kernel :** Le paramètre `net.ipv4.ip_forward=1` doit être activé sur toutes les VMs pour permettre le routage des paquets CNI.
- **Connectivité réseau :** La configuration du bridge réseau peut varier selon votre distribution Linux hôte. Si les VMs n'ont pas accès à Internet (pour télécharger les binaires Kubernetes), vérifiez les règles iptables/nftables de votre hôte.

## Limites de l'overlay (V1)
- Les performances sont limitées par le matériel de la machine hôte (notamment les IOPS du disque, critiques pour etcd).
- La configuration réseau est moins standardisée que sur le Cloud et dépend fortement de l'environnement local de l'utilisateur.
- Pas de Load Balancer externe disponible nativement.
