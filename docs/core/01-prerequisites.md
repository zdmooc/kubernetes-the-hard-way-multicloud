# 01 - Prérequis et Outils Client

**Auteur :** Zidane Djamal

## Objectif
Ce chapitre a pour objectif de préparer l'environnement de travail (votre poste local ou la jumpbox) avec les outils clients nécessaires pour interagir avec l'infrastructure et générer les artefacts cryptographiques (PKI) requis pour Kubernetes.

## Prérequis
- Un accès terminal à votre machine locale (Linux, macOS, ou WSL sur Windows).
- Les droits administrateur (`sudo`) pour installer des binaires.
- Une connexion Internet active.

## Entrées
- Aucune entrée spécifique requise à ce stade.

## Sorties
- Binaires `cfssl` et `cfssljson` installés et fonctionnels.
- Binaire `kubectl` installé et fonctionnel.

## Étapes

### 1. Installation de CFSSL
CFSSL (Cloudflare's PKI and TLS toolkit) est l'outil que nous utiliserons pour générer l'autorité de certification (CA) et tous les certificats TLS du cluster. Il est préféré à `openssl` pour sa capacité à générer des certificats via des fichiers de configuration JSON simples.

Téléchargez et installez les binaires :

```bash
wget -q --show-progress --https-only --timestamping \
  https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssl \
  https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssljson

chmod +x cfssl cfssljson
sudo mv cfssl cfssljson /usr/local/bin/
```

*(Note : Si vous êtes sur macOS, utilisez `brew install cfssl`)*

### 2. Installation de kubectl
`kubectl` est l'outil en ligne de commande officiel pour interagir avec l'API Kubernetes. Bien que le cluster ne soit pas encore créé, nous avons besoin de cet outil localement pour générer les fichiers `kubeconfig` dans les chapitres suivants.

Téléchargez la version spécifique ciblée par ce projet (ex: 1.29.2) :

```bash
wget -q --show-progress --https-only --timestamping \
  "https://dl.k8s.io/release/v1.29.2/bin/linux/amd64/kubectl"

chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

*(Note : Assurez-vous de télécharger la version correspondant à l'architecture de votre machine, par exemple `darwin/arm64` pour les Mac M1/M2).*

## Validations

Vérifiez que les outils sont correctement installés et accessibles dans votre `$PATH` :

```bash
cfssl version
# Doit afficher la version 1.4.1 ou supérieure

kubectl version --client
# Doit afficher Client Version: v1.29.2
```

## Points de vigilance
- **Version de kubectl :** Il est crucial que la version du client `kubectl` ne diffère pas de plus d'une version mineure (skew) par rapport à la version de l'API Server que nous déploierons. Restez sur la version spécifiée dans le tutoriel.
- **Architecture système :** Les commandes ci-dessus téléchargent des binaires pour Linux AMD64 (`linux/amd64`). Adaptez les URLs si vous exécutez ces commandes depuis une autre architecture (ex: ARM64).

## Dépendances
- Ce chapitre ne dépend d'aucun autre. Il doit être exécuté en premier.

## Articulation avec les autres chapitres
Une fois les outils installés, vous êtes prêt à provisionner l'infrastructure (via le provider de votre choix) puis à vous connecter à la `jumpbox` (Chapitre 02) pour commencer la génération de la PKI (Chapitre 03) en utilisant `cfssl`.
