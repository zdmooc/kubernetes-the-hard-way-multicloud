# 04 - Génération des Kubeconfigs

**Auteur :** Zidane Djamal

## Objectif
Ce chapitre explique comment générer les fichiers de configuration Kubernetes (`kubeconfig`). Ces fichiers permettent aux clients (Kubelet, Kube-proxy, Controller Manager, Scheduler, et l'utilisateur Admin) de s'authentifier et de se connecter de manière sécurisée à l'API Server en utilisant les certificats générés au chapitre précédent.

## Prérequis
- L'outil `kubectl` doit être installé sur la `jumpbox`.
- La PKI complète (fichiers `.pem`) doit avoir été générée (Chapitre 03).
- Le fichier `inventory.env` doit être sourcé.

## Entrées
- L'adresse IP publique ou privée du nœud `server` (selon d'où la connexion est initiée).
- Le certificat de l'Autorité de Certification (`ca.pem`).
- Les certificats clients et leurs clés privées (ex: `node-0.pem`, `node-0-key.pem`).

## Sorties
Un ensemble de fichiers `.kubeconfig` générés localement :
- `node-0.kubeconfig`, `node-1.kubeconfig` (pour les Kubelets)
- `kube-proxy.kubeconfig`
- `kube-controller-manager.kubeconfig`
- `kube-scheduler.kubeconfig`
- `admin.kubeconfig`

## Étapes

L'ensemble de ces étapes est automatisé dans le script `scripts/core/03-kubeconfigs.sh`.

La création d'un fichier `kubeconfig` via la CLI `kubectl` se fait systématiquement en trois étapes :
1. **Set Cluster :** Définir l'adresse de l'API Server et le certificat de la CA.
2. **Set Credentials :** Définir le certificat client et la clé privée.
3. **Set Context :** Lier le cluster et les credentials dans un contexte par défaut.

### 1. Kubeconfigs pour les Kubelets (Workers)

Les Kubelets s'exécutent sur les workers. Ils doivent se connecter à l'API Server en utilisant l'adresse IP de ce dernier.

```bash
KUBERNETES_PUBLIC_ADDRESS="${SERVER_PUBLIC_IP}"

for instance in node-0 node-1; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=${instance}.pem \
    --client-key=${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done
```

*(Note : Dans notre topologie, nous utilisons l'IP publique du server pour la configuration initiale depuis l'extérieur, mais en production stricte, les workers utiliseraient l'IP privée `SERVER_PRIVATE_IP`).*

### 2. Kubeconfig pour le Kube-proxy

Le `kube-proxy` s'exécute également sur les workers :

```bash
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=kube-proxy.pem --client-key=kube-proxy-key.pem --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig
```

### 3. Kubeconfigs pour le Control Plane (Localhost)

Le Controller Manager et le Scheduler s'exécutent sur la même machine que l'API Server (le nœud `server`). Par conséquent, ils peuvent communiquer directement via l'interface locale (`127.0.0.1`), ce qui est plus sécurisé et performant.

```bash
# Exemple pour le Controller Manager
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig
# (suivi des set-credentials et set-context)
```

### 4. Distribution des Kubeconfigs

Comme pour les certificats, les fichiers `.kubeconfig` doivent être distribués via `scp` :
- Vers les workers : `node-X.kubeconfig`, `kube-proxy.kubeconfig`
- Vers le server : `admin.kubeconfig`, `kube-controller-manager.kubeconfig`, `kube-scheduler.kubeconfig`

## Validations

Vous pouvez inspecter le contenu d'un fichier généré :

```bash
cat admin.kubeconfig
```
Vous devez y voir les blocs `clusters`, `users`, et `contexts`, avec les certificats encodés en base64 (grâce au flag `--embed-certs=true`).

## Points de vigilance
- **`--embed-certs=true` :** Ce flag est crucial. S'il est omis, le fichier kubeconfig contiendra des chemins absolus vers les fichiers `.pem`. En embarquant les certificats en base64, le fichier kubeconfig devient portable et autonome.
- **Adresse de l'API Server :** Les workers doivent pointer vers une IP joignable (privée ou publique selon l'architecture réseau). Les composants du Control Plane doivent pointer vers `127.0.0.1`.

## Dépendances
- Chapitre 03 (PKI générée).

## Articulation avec les autres chapitres
Ces fichiers seront utilisés lors de la configuration des services systemd du Control Plane (Chapitre 07) et des Workers (Chapitre 08).
