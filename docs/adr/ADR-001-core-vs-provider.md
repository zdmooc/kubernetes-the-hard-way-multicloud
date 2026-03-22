# ADR 001 : Séparation stricte entre le Core et les Providers

**Statut :** Accepté
**Date :** 22-03-2026
**Auteur :** Zidane Djamal

## Contexte

Dans la création d'un laboratoire de déploiement Kubernetes multi-cloud (Kubernetes The Hard Way), la principale difficulté réside dans la gestion des spécificités de chaque fournisseur d'infrastructure (GCP, AWS, Azure, IBM Cloud, On-Premises). Historiquement, les tutoriels de ce type mélangent souvent les commandes de création d'infrastructure (ex: `gcloud compute instances create`) avec les commandes de configuration de Kubernetes (ex: `cfssl`, `kubectl`, `systemctl`).

Ce mélange crée une forte adhérence au fournisseur Cloud choisi. Si un ingénieur souhaite reproduire le même exercice sur un autre Cloud, il doit réécrire ou adapter l'intégralité du tutoriel, ce qui dilue l'apprentissage de Kubernetes au profit de l'apprentissage des APIs Cloud. De plus, cela rend la maintenance du dépôt complexe : une mise à jour de la version de Kubernetes nécessiterait de modifier les scripts de tous les providers.

Il est donc nécessaire de définir une architecture de dépôt qui permette de réutiliser au maximum la logique d'installation de Kubernetes, indépendamment de l'infrastructure sous-jacente.

## Décision

Nous avons décidé d'implémenter une séparation stricte et étanche entre le "Core" (socle Kubernetes) et les "Providers" (infrastructure).

1. **Le Core (`core/`) :** Contient exclusivement les scripts, configurations et documentations agnostiques à l'infrastructure. Ces éléments traitent de la génération de la PKI, de la création des kubeconfigs, du chiffrement, et de la configuration des binaires Kubernetes (`etcd`, `kube-apiserver`, `kubelet`, etc.). Le Core ne connaît que des adresses IP, des clés SSH et des hostnames standards.
2. **Les Providers (`providers/` et `terraform/`) :** Contiennent exclusivement le code (Terraform) et la documentation nécessaires au provisionnement des ressources d'infrastructure (VPC, VMs, Security Groups).
3. **Le Contrat d'Interface (Inventory) :** La jonction entre le Provider et le Core est assurée par un fichier d'inventaire standardisé (`inventory.env`). Ce fichier est généré dynamiquement par le Provider à la fin de son exécution et est sourcé par les scripts du Core. Il contient toutes les variables dynamiques (IPs publiques, IPs privées) nécessaires au Core.

## Conséquences

### Conséquences positives
- **Réutilisabilité maximale :** Le code d'installation de Kubernetes est écrit une seule fois. Une mise à jour de la version de Kubernetes (ex: passage de 1.29 à 1.30) ne nécessite de modifier que les scripts du Core.
- **Agnosticité prouvée :** L'architecture démontre concrètement que Kubernetes fonctionne de manière identique partout, démystifiant ainsi la dépendance aux offres managées.
- **Évolutivité facilitée :** L'ajout d'un nouveau fournisseur Cloud (ex: Oracle Cloud, Scaleway) se résume à écrire un nouveau module Terraform qui respecte le contrat d'interface (génération du fichier `inventory.env`), sans toucher au Core.
- **Apprentissage ciblé :** L'utilisateur peut se concentrer uniquement sur Kubernetes s'il le souhaite, en utilisant un environnement pré-provisionné.

### Conséquences négatives
- **Complexité initiale :** La mise en place du contrat d'interface (injection dynamique des IPs dans les certificats, gestion de l'inventaire) demande un effort d'ingénierie supérieur à l'écriture d'un script monolithique.
- **Abstraction de l'automatisation :** Pour maintenir la pureté du "Hard Way", l'automatisation de la jonction entre le Provider et le Core reste manuelle en V1 (l'utilisateur doit se connecter à la jumpbox et sourcer l'inventaire).

## Alternatives écartées

- **Scripts monolithiques par provider :** Avoir un répertoire `gcp/` contenant à la fois le code Terraform et des scripts bash spécifiques (ex: `gcp-pki.sh`, `gcp-etcd.sh`). Écarté car cela engendre une duplication massive de code (DRY non respecté) et un cauchemar de maintenance.
- **Utilisation d'outils d'installation existants (kubeadm, kubespray) :** Écarté car cela va à l'encontre de l'objectif pédagogique fondamental du projet "The Hard Way", qui est de comprendre les mécanismes internes par la pratique manuelle.
- **Abstraction via Ansible dès la V1 :** Écarté pour la V1. Bien qu'Ansible soit excellent pour séparer l'inventaire de la logique, son introduction immédiate masquerait trop les commandes sous-jacentes. L'automatisation Ansible est réservée pour une phase ultérieure (V2).
