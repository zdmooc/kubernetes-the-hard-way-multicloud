# ADR 003 : Utilisation d'Overlays Provider pour l'Infrastructure

**Statut :** Accepté
**Date :** 22-03-2026
**Auteur :** Zidane Djamal

## Contexte

Dans le cadre du projet "Kubernetes The Hard Way Multi-Cloud", la volonté de déployer sur cinq environnements différents (GCP, AWS, Azure, IBM Cloud, On-Premises) pose un défi d'hétérogénéité. Chaque fournisseur Cloud possède ses propres concepts, ses propres API et ses propres contraintes de sécurité et de réseau.

Par exemple, le routage du trafic des pods (Pod CIDR) entre les nœuds workers est géré nativement par GCP via des "Routes" au niveau du VPC, tandis que sur AWS, il faut désactiver le "Source/Destination Check" sur les interfaces réseau EC2. Sur Azure, il faut configurer l' "IP Forwarding" sur les NICs et créer des "User Defined Routes".

Tenter d'unifier ces concepts dans un seul module d'infrastructure générique (par exemple via un outil agnostique qui abstrait trop les détails) créerait une usine à gaz difficile à maintenir et masquerait les spécificités que l'ingénieur plateforme doit précisément comprendre.

## Décision

Nous avons décidé d'adopter un modèle d'architecture par "Overlays Provider".

1. **Isolation :** Chaque provider dispose de son propre répertoire dédié (`terraform/<provider>/` et `docs/providers/<provider>/`).
2. **Aucun code partagé au niveau infra :** Il n'y a pas de module Terraform racine qui appellerait des sous-modules provider. Chaque overlay est un projet Terraform indépendant et complet (standalone).
3. **Contrat de sortie strict :** Le seul point commun exigé de chaque overlay est la production d'un livrable standardisé : le fichier `inventory.env` et la configuration de l'accès SSH via une clé publique injectée.
4. **Responsabilité de l'Overlay :** L'overlay est responsable de tout ce qui précède l'installation de Kubernetes : VPC, Subnets, Security Groups/Firewalls, VMs, adresses IP (publiques et privées), et configuration du routage bas niveau nécessaire au Pod CIDR.

## Conséquences

### Conséquences positives
- **Clarté d'apprentissage :** L'utilisateur qui souhaite apprendre le déploiement sur AWS n'est pas pollué par du code ou des conditions liées à Azure ou GCP. Le code Terraform d'un overlay est idiomatique et respecte les meilleures pratiques du provider ciblé.
- **Débogage facilité :** En cas d'erreur lors de la création de l'infrastructure, le périmètre d'investigation est restreint au répertoire du provider concerné.
- **Flexibilité de contribution :** Un contributeur expert sur IBM Cloud peut améliorer l'overlay IBM sans risquer de casser les déploiements GCP ou AWS.
- **Adaptation aux contraintes locales :** L'overlay On-Premises peut utiliser des outils totalement différents (scripts bash, libvirt) tout en respectant le contrat de sortie (l'inventory), prouvant la flexibilité du modèle.

### Conséquences négatives
- **Duplication de logique (WET - Write Everything Twice) :** Des concepts similaires (création d'un réseau, création de 4 VMs) sont codés 5 fois différemment. C'est un compromis assumé pour privilégier la lisibilité et l'indépendance.
- **Maintenance multiple :** Si une évolution de la topologie standard (ADR-002) est décidée (ex: ajout d'un nœud), il faudra modifier le code d'infrastructure dans les 5 overlays.

## Alternatives écartées

- **Module Terraform Multi-Cloud unique :** Utiliser des modules abstraits ou des outils comme Pulumi pour tenter d'écrire l'infrastructure une seule fois. Écarté car cela crée une abstraction fuyante (le "Lowest Common Denominator") qui empêche d'utiliser les fonctionnalités spécifiques et optimisées de chaque Cloud.
- **Outils de provisionnement Kubernetes natifs (Cluster API) :** Bien que Cluster API (CAPI) soit le standard industriel pour le multi-cloud, son utilisation en V1 masque totalement la création de l'infrastructure sous-jacente (VPC, VMs), ce qui va à l'encontre de la philosophie "Hard Way". CAPI est une solution cible pour la production, pas pour ce laboratoire d'apprentissage fondamental.
