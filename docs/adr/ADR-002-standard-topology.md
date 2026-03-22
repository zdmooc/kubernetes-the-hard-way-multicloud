# ADR 002 : Topologie Logique Standard Unique

**Statut :** Accepté
**Date :** 22-03-2026
**Auteur :** Zidane Djamal

## Contexte

Pour que les scripts du socle commun (Core) puissent fonctionner indifféremment sur n'importe quel fournisseur d'infrastructure (GCP, AWS, Azure, etc.), il est impératif que l'environnement cible présente une structure prévisible. Si un provider déploie 3 workers et un autre en déploie 5, ou si les noms d'hôtes varient (ex: `master-1` vs `control-plane-0`), les scripts de génération de certificats (PKI) et de configuration devront inclure des boucles complexes et des conditions spécifiques, ce qui viole le principe de séparation établi dans l'ADR-001.

L'objectif de la V1 est pédagogique : comprendre les rouages de Kubernetes. Une topologie trop complexe (haute disponibilité, multiples zones) ajoute du bruit cognitif et des coûts d'infrastructure inutiles pour un laboratoire initial.

## Décision

Nous avons décidé d'imposer une topologie logique standard, immuable et minimaliste pour tous les déploiements de la V1. Cette topologie se compose de quatre nœuds avec des rôles et des noms d'hôtes strictement définis :

1. **`jumpbox` (Bastion / Outils) :** Point d'entrée unique. C'est ici que l'utilisateur se connecte, génère la PKI, et distribue les artefacts vers les autres nœuds.
2. **`server` (Control Plane) :** Nœud unique hébergeant les composants de contrôle (`etcd`, `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`).
3. **`node-0` (Worker 0) :** Premier nœud d'exécution des charges de travail (`kubelet`, `kube-proxy`, `containerd`).
4. **`node-1` (Worker 1) :** Second nœud d'exécution des charges de travail.

Ces noms d'hôtes (`jumpbox`, `server`, `node-0`, `node-1`) doivent être résolubles localement au sein du cluster.

## Conséquences

### Conséquences positives
- **Simplicité des scripts Core :** Les scripts n'ont pas besoin de gérer des tableaux dynamiques complexes. Ils peuvent référencer directement les variables `SERVER_PRIVATE_IP`, `NODE_0_PRIVATE_IP`, etc.
- **Lisibilité de la documentation :** Les guides pas à pas peuvent fournir des commandes exactes à copier-coller (ex: `ssh ubuntu@node-0`), sans obliger l'utilisateur à remplacer des variables mentalement.
- **Maîtrise des coûts :** Une topologie à 4 nœuds maintient les coûts d'infrastructure à un niveau acceptable pour un projet d'apprentissage personnel.
- **Focus sur l'essentiel :** Deux workers sont suffisants pour démontrer les concepts de réseau inter-nœuds (Pod-to-Pod communication) et de répartition de charge (Service LoadBalancing), sans la complexité de gestion d'un grand parc.

### Conséquences négatives
- **Pas de Haute Disponibilité (HA) :** Le nœud `server` représente un Single Point of Failure (SPOF). Si ce nœud tombe, l'API Kubernetes devient indisponible (bien que les charges de travail sur les workers continuent de tourner).
- **Rigidité :** L'utilisateur ne peut pas facilement tester le déploiement de 10 workers en modifiant simplement une variable Terraform, car les scripts Core de la V1 s'attendent explicitement à `node-0` et `node-1`.

## Alternatives écartées

- **Topologie HA d'emblée (3 Control Planes, 3 Workers) :** Écartée pour la V1. La mise en place d'un cluster `etcd` distribué et d'un Load Balancer devant les API Servers ajoute une complexité significative qui masque les fondamentaux. Cela fera l'objet d'une itération future (V3).
- **Nombre de workers dynamique :** Écarté. Bien que Terraform puisse facilement créer `N` workers, la gestion dynamique de la PKI (générer un certificat par worker de manière dynamique en bash pur) complexifie excessivement les scripts pédagogiques.
- **Topologie mono-nœud (Minikube-like) :** Écartée. Déployer le Control Plane et le Worker sur la même machine ne permet pas de démontrer les concepts cruciaux de réseau CNI et de routage inter-nœuds, qui sont au cœur du "Hard Way".
