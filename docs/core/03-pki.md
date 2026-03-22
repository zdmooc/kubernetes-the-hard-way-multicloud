# 03 - Infrastructure à Clé Publique (PKI)

**Auteur :** Zidane Djamal

## Objectif
Ce chapitre explique comment générer manuellement l'Infrastructure à Clé Publique (PKI) requise pour sécuriser un cluster Kubernetes. Kubernetes exige que toutes les communications entre ses composants (API Server, Kubelet, etcd, etc.) soient chiffrées et authentifiées mutuellement (mTLS). Nous allons créer une Autorité de Certification (CA) racine, puis générer les certificats clients et serveurs pour chaque composant.

## Prérequis
- Outils `cfssl` et `cfssljson` installés (Chapitre 01).
- Être connecté sur la `jumpbox` avec le fichier `inventory.env` sourcé (Chapitre 02).

## Entrées
- Variables d'environnement IP issues de `inventory.env` (`SERVER_PRIVATE_IP`, `NODE_0_PRIVATE_IP`, etc.).

## Sorties
Un ensemble de fichiers `.pem` et `.csr` générés dans un répertoire local (ex: `certs/`), comprenant :
- `ca.pem`, `ca-key.pem` : La Certificate Authority.
- `admin.pem`, `admin-key.pem` : Certificat client pour l'utilisateur admin.
- `node-0.pem`, `node-1.pem` : Certificats clients pour les Kubelets.
- `kube-controller-manager.pem`, `kube-scheduler.pem`, `kube-proxy.pem` : Certificats clients pour les composants du control plane.
- `kubernetes.pem`, `kubernetes-key.pem` : Certificat serveur pour l'API Kubernetes.
- `service-account.pem`, `service-account-key.pem` : Clés pour la signature des Service Accounts.

## Étapes

L'ensemble de ces étapes est automatisé dans le script `scripts/core/02-pki.sh`. Voici le détail de ce qui s'y passe :

### 1. Création de l'Autorité de Certification (CA)

Nous créons d'abord la CA qui signera tous les autres certificats :

```bash
cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": { "algo": "rsa", "size": 2048 },
  "names": [ { "C": "FR", "L": "Paris", "O": "Kubernetes", "OU": "CA", "ST": "Ile-de-France" } ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

### 2. Certificats Clients (Admin, Kubelet, Controller, Scheduler, Proxy)

Pour chaque composant client, nous générons un certificat signé par la CA.
**Point crucial pour le RBAC :** Le champ `O` (Organization) définit le groupe Kubernetes, et `CN` (Common Name) définit l'utilisateur.

- **Admin :** `O=system:masters`, `CN=admin`
- **Kubelets :** `O=system:nodes`, `CN=system:node:<hostname>` (ex: `system:node:node-0`)
- **Controller Manager :** `O=system:kube-controller-manager`, `CN=system:kube-controller-manager`

Exemple pour `node-0` :
```bash
cat > node-0-csr.json <<EOF
{
  "CN": "system:node:node-0",
  "key": { "algo": "rsa", "size": 2048 },
  "names": [ { "C": "FR", "L": "Paris", "O": "system:nodes", "OU": "Kubernetes The Hard Way", "ST": "Ile-de-France" } ]
}
EOF

cfssl gencert \
  -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes \
  node-0-csr.json | cfssljson -bare node-0
```

### 3. Certificat Serveur (API Server)

Le certificat de l'API Server est le plus complexe car il doit inclure dans ses SANs (Subject Alternative Names) toutes les adresses IP et noms DNS par lesquels les clients pourraient tenter de le joindre.

C'est ici que l'injection dynamique via `inventory.env` prend tout son sens :
```bash
KUBERNETES_HOSTNAMES="kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local"

cfssl gencert \
  -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes \
  -hostname=10.32.0.1,${SERVER_PRIVATE_IP},${SERVER_PUBLIC_IP},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  kubernetes-csr.json | cfssljson -bare kubernetes
```
*(Note : `10.32.0.1` est la première IP du `SERVICE_CIDR`, réservée au service `kubernetes.default`).*

### 4. Distribution des certificats

Une fois générés, les certificats doivent être copiés via `scp` vers les nœuds respectifs :
- Vers les workers : `ca.pem`, `node-X.pem`, `node-X-key.pem`
- Vers le server : `ca.pem`, `ca-key.pem`, `kubernetes.pem`, `kubernetes-key.pem`, `service-account.pem`, `service-account-key.pem`

## Validations

Vous pouvez vérifier le contenu du certificat de l'API Server pour confirmer que les IPs ont été correctement injectées :

```bash
openssl x509 -in kubernetes.pem -text -noout | grep -A 2 "Subject Alternative Name"
```
Vous devriez voir les IPs privées et publiques de votre nœud `server`.

## Points de vigilance
- **SANs manquants :** Si vous oubliez l'IP publique du `server` dans les SANs, vous ne pourrez pas utiliser `kubectl` depuis votre machine locale.
- **Groupes RBAC (Champ O) :** Une faute de frappe dans `system:masters` ou `system:nodes` empêchera l'authentification et l'autorisation des composants.
- **Sécurité des clés privées :** Les fichiers `-key.pem` ne doivent jamais être partagés ou commités dans Git.

## Dépendances
- Chapitre 02 (Variables d'inventaire sourcées).

## Articulation avec les autres chapitres
Maintenant que nous avons les identités cryptographiques, nous pouvons les intégrer dans des fichiers de configuration Kubernetes (`kubeconfigs`) au Chapitre 04, qui permettront aux composants de se connecter à l'API Server.
