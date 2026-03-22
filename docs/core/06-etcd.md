# 06 - Déploiement du cluster etcd

**Auteur :** Zidane Djamal

## Objectif
Ce chapitre explique comment installer et configurer `etcd`, la base de données clé-valeur distribuée et consistante qui stocke l'intégralité de l'état du cluster Kubernetes. Pour la V1, nous déploierons un cluster `etcd` mono-nœud sur le serveur `server`.

## Prérequis
- Avoir distribué la PKI (Chapitre 03) sur le nœud `server` (`ca.pem`, `kubernetes-key.pem`, `kubernetes.pem`).
- Avoir un accès SSH au nœud `server`.

## Entrées
- Binaire `etcd` (téléchargé lors de cette étape).
- Variables d'inventaire (IP privée du `server`).

## Sorties
- Le service `etcd` installé, configuré en tant que service `systemd` et en cours d'exécution sur le nœud `server`.

## Étapes

L'ensemble de ces étapes est automatisé dans le script `scripts/core/05-etcd.sh`, qui est conçu pour être exécuté *depuis la jumpbox* via SSH vers le nœud `server`.

### 1. Téléchargement et installation des binaires

Connectez-vous au nœud `server` et téléchargez les binaires officiels d'etcd :

```bash
wget -q --show-progress --https-only --timestamping \
  "https://github.com/etcd-io/etcd/releases/download/v3.5.12/etcd-v3.5.12-linux-amd64.tar.gz"

tar -xvf etcd-v3.5.12-linux-amd64.tar.gz
sudo mv etcd-v3.5.12-linux-amd64/etcd* /usr/local/bin/
```

### 2. Configuration des répertoires et des certificats

etcd a besoin d'un répertoire pour stocker ses données (le WAL et les snapshots) et d'un répertoire pour ses certificats TLS :

```bash
sudo mkdir -p /etc/etcd /var/lib/etcd
sudo chmod 700 /var/lib/etcd
sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
```

*(Note : Nous réutilisons le certificat `kubernetes.pem` pour etcd car il contient l'IP du server et `127.0.0.1` dans ses SANs, ce qui est suffisant pour ce lab. En production stricte, etcd aurait sa propre CA et ses propres certificats peer/server).*

### 3. Création du service systemd

Nous créons le fichier unit `systemd` pour gérer le cycle de vie du processus etcd :

```bash
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name server \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${SERVER_PRIVATE_IP}:2380 \\
  --listen-peer-urls https://${SERVER_PRIVATE_IP}:2380 \\
  --listen-client-urls https://${SERVER_PRIVATE_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${SERVER_PRIVATE_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster server=https://${SERVER_PRIVATE_IP}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

**Explication des flags clés :**
- `--name` : Identifiant unique du nœud dans le cluster etcd.
- `--listen-client-urls` : Sur quelles IPs etcd écoute les requêtes des clients (comme l'API Server). Nous incluons `127.0.0.1` pour les requêtes locales et l'IP privée pour les requêtes externes.
- `--listen-peer-urls` : Sur quelles IPs etcd écoute les autres membres du cluster etcd (pour la synchronisation Raft).
- `--initial-cluster` : Liste des membres initiaux du cluster. Ici, un seul membre (`server`).

### 4. Démarrage du service

```bash
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd
```

## Validations

Vérifiez que le cluster etcd est fonctionnel en interrogeant son API locale. Vous devez utiliser les certificats pour vous authentifier :

```bash
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
```

Le résultat doit afficher un membre avec le nom `server` et le statut `started`.

## Points de vigilance
- **Certificats (mTLS) :** etcd est configuré avec `--client-cert-auth` et `--peer-client-cert-auth`. Il refusera toute connexion qui ne présente pas un certificat valide signé par `ca.pem`.
- **Performance disque :** etcd est extrêmement sensible à la latence disque (fsync). Si le disque de la VM est trop lent (IOPS insuffisants), etcd affichera des warnings `took too long to execute` et le cluster Kubernetes sera instable. C'est pourquoi des disques SSD (Premium, gp3, pd-ssd) ont été choisis dans les LLDs.

## Dépendances
- Chapitre 03 (PKI).

## Articulation avec les autres chapitres
Une fois etcd démarré et sain, l'API Server (Chapitre 07) pourra s'y connecter pour stocker l'état du cluster Kubernetes. Sans etcd, l'API Server refusera de démarrer.
