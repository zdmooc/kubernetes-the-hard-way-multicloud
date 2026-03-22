# 09 - Smoke Tests (Validation)

**Auteur :** Zidane Djamal

## Objectif
Ce chapitre a pour objectif de valider le bon fonctionnement global du cluster Kubernetes fraîchement déployé. Les "Smoke Tests" (tests de fumée) vérifient que toutes les couches de l'architecture communiquent correctement : le chiffrement au repos, le déploiement de conteneurs, le routage réseau inter-nœuds, et la récupération des logs.

## Prérequis
- Le cluster doit être entièrement déployé (Control Plane et Workers `Ready`).
- Le fichier `admin.kubeconfig` doit être configuré sur la machine exécutant les tests (la `jumpbox` ou votre poste local).
- La commande `kubectl` doit être fonctionnelle.

## Entrées
- Le cluster Kubernetes actif.

## Sorties
- Des preuves d'exécution validant chaque fonctionnalité clé.

## Étapes

L'ensemble de ces étapes est automatisé dans le script `scripts/core/09-smoke-tests.sh`.

### 1. Validation du Chiffrement au Repos

Nous vérifions que les secrets sont bien chiffrés dans etcd (et non stockés en clair).

```bash
# 1. Création d'un secret
kubectl create secret generic kubernetes-the-hard-way --from-literal="mykey=mydata"

# 2. Lecture directe dans etcd (depuis le nœud server)
# La sortie doit contenir "k8s:enc:aescbc:v1:" et NON le mot "mydata" en clair
sudo ETCDCTL_API=3 etcdctl get \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem \
  /registry/secrets/default/kubernetes-the-hard-way | hexdump -C
```

### 2. Validation des Déploiements

Nous vérifions que le Control Plane peut planifier des pods sur les workers et que le Container Runtime (`containerd`) peut télécharger et exécuter des images.

```bash
# Création d'un déploiement Nginx
kubectl create deployment nginx --image=nginx:latest

# Vérification du statut (attendre que le pod soit Running)
kubectl get pods -l app=nginx
```

### 3. Validation du Port Forwarding

Nous vérifions que l'API Server peut communiquer avec le Kubelet pour établir un tunnel réseau direct vers un pod.

```bash
POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")

# Lancement du port-forward en tâche de fond
kubectl port-forward $POD_NAME 8080:80 &
PID=$!

# Test de connexion locale
curl --head http://127.0.0.1:8080

# Arrêt du port-forward
kill $PID
```
La commande `curl` doit retourner un code `HTTP/1.1 200 OK`.

### 4. Validation des Logs

Nous vérifions que l'API Server peut récupérer les logs générés par le Container Runtime via le Kubelet.

```bash
kubectl logs $POD_NAME
```
La sortie doit afficher les logs d'accès Nginx générés par le `curl` précédent.

### 5. Validation de l'Exécution de Commandes (Exec)

Nous vérifions la capacité d'exécuter des commandes interactives à l'intérieur d'un conteneur en cours d'exécution.

```bash
kubectl exec -ti $POD_NAME -- nginx -v
```
La sortie doit afficher la version de Nginx (ex: `nginx version: nginx/1.25.x`).

### 6. Validation des Services (Routage Kube-proxy)

Nous vérifions que le `kube-proxy` route correctement le trafic réseau d'un Service vers les Pods sous-jacents, et que les pods peuvent communiquer entre eux à travers les nœuds (Pod-to-Pod communication).

```bash
# Exposition du déploiement via un Service de type NodePort
kubectl expose deployment nginx --port 80 --type NodePort

# Récupération du NodePort assigné
NODE_PORT=$(kubectl get svc nginx -o jsonpath="{.spec.ports[0].nodePort}")

# Test de connexion depuis la jumpbox vers l'IP d'un worker sur le NodePort
# (Remplacez NODE_0_PRIVATE_IP par la valeur réelle)
curl -I http://${NODE_0_PRIVATE_IP}:${NODE_PORT}
```
La commande doit retourner un code `HTTP/1.1 200 OK`, prouvant que le trafic est entré par le worker 0, a été routé par kube-proxy (iptables), et a atteint le pod Nginx (qui peut potentiellement s'exécuter sur le worker 1).

## Validations

Si toutes les commandes ci-dessus s'exécutent sans erreur et retournent les résultats attendus, le cluster est considéré comme pleinement fonctionnel.

## Points de vigilance
- **Erreurs de Port-Forward / Logs / Exec :** Si ces commandes échouent (ex: `error: error upgrading connection`), c'est généralement lié à un problème de RBAC (Chapitre 07) ou à un certificat Kubelet mal configuré (Chapitre 03/08).
- **Timeout sur le Service NodePort :** Si le `curl` sur le NodePort part en timeout, c'est que le routage réseau de l'infrastructure (Security Groups, Firewalls, IP Forwarding) bloque le trafic inter-nœuds.

## Dépendances
- Le cluster complet (Control Plane et Workers).

## Articulation avec les autres chapitres
Ce chapitre clôture le cycle de déploiement Core. Les traces générées par ces tests doivent être conservées dans le répertoire `evidence/` pour prouver le succès du déploiement sur le provider choisi. Une fois validé, vous pouvez procéder au nettoyage de l'infrastructure (Cleanup).
