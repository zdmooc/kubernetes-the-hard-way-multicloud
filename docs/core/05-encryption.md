# 05 - Chiffrement des Secrets au Repos

**Auteur :** Zidane Djamal

## Objectif
Ce chapitre explique comment configurer Kubernetes pour chiffrer les données sensibles (comme les objets `Secret`) avant de les stocker dans la base de données `etcd`. Par défaut, Kubernetes stocke les secrets en clair (encodés en base64) dans etcd. En cas de compromission du disque ou d'un snapshot etcd, les secrets seraient exposés. Le chiffrement au repos (Encryption at Rest) atténue ce risque.

## Prérequis
- Avoir complété les chapitres précédents.
- Être sur la `jumpbox`.

## Entrées
- Aucune entrée externe requise. La clé de chiffrement sera générée aléatoirement.

## Sorties
- Une clé de chiffrement générée (32 octets, encodée en base64).
- Le fichier de configuration `encryption-config.yaml`.

## Étapes

L'ensemble de ces étapes est automatisé dans le script `scripts/core/04-encryption-config.sh`.

### 1. Génération de la clé de chiffrement

Nous utilisons l'outil système `head` et `/dev/urandom` pour générer une clé cryptographique forte de 32 octets, que nous encodons ensuite en base64 :

```bash
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
```

### 2. Création du fichier de configuration (EncryptionConfig)

Nous créons ensuite le fichier YAML que l'API Server utilisera pour savoir comment chiffrer les données. Nous configurons le provider `aescbc` (AES-CBC avec PKCS#7 padding) qui est un algorithme symétrique robuste.

```bash
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
```

**Explication de la configuration :**
- `resources: - secrets` : Indique que seuls les objets de type `Secret` doivent être chiffrés.
- `aescbc` : Le premier provider listé est celui utilisé pour le chiffrement des nouveaux secrets.
- `identity: {}` : Ce provider de secours (fallback) indique que l'API Server doit quand même être capable de lire les données stockées en clair (celles créées avant l'activation du chiffrement).

### 3. Distribution du fichier

Le fichier `encryption-config.yaml` doit être copié exclusivement sur le nœud `server` (Control Plane), car seul l'API Server en a besoin pour communiquer avec etcd.

```bash
scp -i ~/.ssh/id_ed25519 encryption-config.yaml ubuntu@${SERVER_PUBLIC_IP}:~/
```

## Validations

Inspectez le fichier généré localement pour vérifier sa structure :

```bash
cat encryption-config.yaml
```
Vérifiez que la valeur du champ `secret` est bien une chaîne base64 non vide.

## Points de vigilance
- **Perte de la clé :** Si vous perdez ce fichier ou cette clé et que l'API Server redémarre, vous perdrez définitivement l'accès à tous les secrets stockés dans le cluster. Il est impératif de sauvegarder cette clé en production (via un coffre-fort comme HashiCorp Vault ou AWS KMS, bien que la V1 utilise un fichier local pour la simplicité).
- **Rotation des clés :** La configuration permet d'ajouter plusieurs clés sous le bloc `keys`. Lors d'une rotation, on ajoute la nouvelle clé en premier (pour le chiffrement des nouvelles données) tout en gardant l'ancienne (pour déchiffrer les données existantes), puis on force la réécriture des secrets.

## Dépendances
- Ce fichier doit être présent sur le nœud `server` avant de démarrer le service `kube-apiserver` (Chapitre 07).

## Articulation avec les autres chapitres
Ce fichier de configuration sera passé en paramètre à l'API Server (`--encryption-provider-config`) lors du déploiement du Control Plane. Nous validerons l'efficacité de ce chiffrement lors des Smoke Tests (Chapitre 09) en interrogeant directement etcd.
