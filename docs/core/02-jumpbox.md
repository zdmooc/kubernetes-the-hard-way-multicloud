# 02 - Configuration de la Jumpbox

**Auteur :** Zidane Djamal

## Objectif
Ce chapitre explique comment configurer et utiliser la `jumpbox` (bastion). La jumpbox est le point d'entrée unique de votre infrastructure. C'est depuis cette machine que nous allons exécuter tous les scripts de configuration, générer les certificats, et distribuer les fichiers vers les nœuds du cluster (`server`, `node-0`, `node-1`).

## Prérequis
- Avoir exécuté le provisionnement de l'infrastructure via l'un des overlays Provider (ex: Terraform GCP ou AWS).
- Avoir généré avec succès le fichier `inventory.env` via l'overlay Provider.
- Posséder la clé SSH privée correspondant à la clé publique déployée sur l'infrastructure.

## Entrées
- Le fichier `inventories/<provider>/inventory.env` généré par le provisionnement.
- La clé SSH privée (ex: `~/.ssh/id_ed25519`).

## Sorties
- Une session SSH active sur la `jumpbox`.
- Le dépôt Git cloné sur la `jumpbox`.
- Les variables d'environnement sourcées dans la session active.

## Étapes

### 1. Connexion à la Jumpbox

Utilisez l'adresse IP publique de la jumpbox (trouvable dans votre fichier `inventory.env` ou via les outputs Terraform) pour vous y connecter :

```bash
# Exemple générique, remplacez par votre IP publique et utilisateur (ubuntu, root, etc.)
ssh -i ~/.ssh/id_ed25519 ubuntu@<JUMPBOX_PUBLIC_IP>
```

### 2. Clonage du dépôt

Une fois connecté sur la jumpbox, clonez ce dépôt pour avoir accès aux scripts d'automatisation du socle Core :

```bash
git clone https://github.com/zdmooc/kubernetes-the-hard-way-multicloud.git
cd kubernetes-the-hard-way-multicloud
```

### 3. Installation des outils sur la Jumpbox

Bien que nous ayons installé `cfssl` et `kubectl` en local au chapitre 01, il est préférable de faire la génération depuis la jumpbox pour centraliser les fichiers. Exécutez le script d'installation des prérequis sur la jumpbox :

```bash
./scripts/core/01-prerequisites.sh
```

### 4. Configuration de l'inventaire

Copiez le fichier `inventory.env` généré par votre provider (depuis votre machine locale) vers la jumpbox. Vous pouvez utiliser `scp` depuis votre machine locale :

```bash
# Depuis votre machine locale
scp -i ~/.ssh/id_ed25519 inventories/gcp/inventory.env ubuntu@<JUMPBOX_PUBLIC_IP>:~/kubernetes-the-hard-way-multicloud/inventory.env
```

Puis, sur la jumpbox, sourcez ce fichier pour charger toutes les variables d'adresses IP dans votre session courante :

```bash
# Sur la jumpbox
source inventory.env
```

### 5. Vérification de la connectivité interne

Vérifiez que la jumpbox peut communiquer avec les autres nœuds en utilisant leurs adresses IP privées. Pour cela, vous devez transférer votre clé SSH privée sur la jumpbox (ou utiliser le SSH Agent Forwarding `-A`).

```bash
# Test de connexion vers le server
ssh -o StrictHostKeyChecking=no ${SSH_USER}@${SERVER_PRIVATE_IP} exit

# Test de connexion vers les workers
ssh -o StrictHostKeyChecking=no ${SSH_USER}@${NODE_0_PRIVATE_IP} exit
ssh -o StrictHostKeyChecking=no ${SSH_USER}@${NODE_1_PRIVATE_IP} exit
```

## Validations

- La commande `echo $SERVER_PRIVATE_IP` doit retourner une adresse IP valide (ex: `10.240.0.11`).
- Les commandes SSH vers les nœuds internes doivent réussir sans demander de mot de passe.

## Points de vigilance
- **Perte de session :** Si vous vous déconnectez de la jumpbox, vous devrez re-sourcer le fichier `inventory.env` (`source inventory.env`) lors de votre prochaine connexion, sinon les scripts suivants échoueront car les variables IP seront vides.
- **Sécurité de la clé privée :** Copier une clé privée sur une jumpbox dans le cloud est une pratique de laboratoire. En production, on utilise systématiquement le SSH Agent Forwarding (`ssh -A`) pour ne jamais stocker de clé privée sur une machine intermédiaire.

## Dépendances
- Chapitre 01 (Prérequis)
- Provisionnement d'un Provider (GCP, AWS, etc.)

## Articulation avec les autres chapitres
Maintenant que la jumpbox est configurée et que les variables d'infrastructure sont chargées en mémoire, nous pouvons utiliser cette machine comme "tour de contrôle" pour générer la PKI (Chapitre 03) et la distribuer aux autres nœuds.
