# Low Level Design (LLD) Global : Kubernetes The Hard Way Multi-Cloud

**Version :** 1.0.0
**Auteur :** Zidane Djamal, Architecte technique senior, spécialisé en transformation Cloud Native, Kubernetes/OpenShift, modernisation de plateformes critiques, standardisation multi-environnements et industrialisation progressive.

---

## 1. Structure Interne du Dépôt

Le dépôt est organisé pour refléter la séparation stricte entre le socle commun Kubernetes (Core) et les spécificités de l'infrastructure (Providers). Cette structure modulaire garantit la réutilisabilité et la maintenabilité du code.

```text
kubernetes-the-hard-way-multicloud/
├── README.md
├── docs/
│   ├── hld/
│   │   └── HLD.md
│   ├── lld/
│   │   ├── LLD-global.md
│   │   ├── gcp.md
│   │   ├── aws.md
│   │   ├── azure.md
│   │   ├── ibmcloud.md
│   │   └── onprem.md
│   ├── adr/
│   ├── core/
│   └── providers/
├── terraform/
│   ├── gcp/
│   ├── aws/
│   ├── azure/
│   ├── ibmcloud/
│   └── onprem/
├── scripts/
│   ├── core/
│   └── providers/
├── inventories/
│   ├── gcp/
│   ├── aws/
│   ├── azure/
│   ├── ibmcloud/
│   └── onprem/
├── examples/
└── evidence/
```

---

## 2. Conventions de Nommage

Afin d'assurer une cohérence globale à travers tous les environnements, les conventions suivantes s'appliquent strictement :

- **Hostnames (Nœuds) :** `jumpbox`, `server`, `node-0`, `node-1`. Ces noms doivent être résolubles en interne au sein du même réseau.
- **Ressources Cloud (Terraform) :** Préfixées par `k8s-thw-` (ex: `k8s-thw-vpc`, `k8s-thw-subnet`, `k8s-thw-server`).
- **Variables d'Environnement :** Toujours en majuscules avec des underscores (ex: `KUBERNETES_VERSION`, `POD_CIDR`).
- **Scripts d'Exécution :** Préfixés par un numéro séquentiel à deux chiffres indiquant l'ordre d'exécution (ex: `01-provisioning.sh`, `02-pki.sh`, `03-kubeconfigs.sh`).
- **Certificats PKI :** Le nom du fichier correspond au Common Name (CN) ou à la fonction du certificat (ex: `ca.pem`, `admin.pem`, `kube-proxy.pem`, `server.pem`).

---

## 3. Découpage Core / Providers / Inventories / Evidence

### 3.1. Le Core (`core/`)
Le répertoire `core/` (que ce soit dans `docs/` ou `scripts/`) contient exclusivement la logique agnostique à l'infrastructure. Il s'agit des commandes `kubectl`, `cfssl`, des configurations systemd, et des binaires Kubernetes. Aucun identifiant de cloud provider, aucune adresse IP statique externe, ni aucune commande spécifique à une API Cloud ne doit s'y trouver.

### 3.2. Les Providers (`providers/` et `terraform/`)
Chaque sous-répertoire de provider encapsule la logique de création des ressources physiques ou virtuelles (VPC, Subnets, VMs, Security Groups, IAM Roles si applicables). Le code Terraform de chaque provider est autonome et ne partage pas d'état avec les autres.

### 3.3. Les Inventaires (`inventories/`)
L'inventaire est le pivot central de l'architecture. C'est un fichier généré dynamiquement par le provider (via les outputs Terraform) qui mappe les noms logiques (`server`, `node-0`) vers les adresses IP réelles (publiques pour SSH, privées pour la communication interne).

### 3.4. Les Preuves (`evidence/`)
Ce répertoire stocke les traces d'exécution (logs de création Terraform, sorties de commandes `kubectl get nodes`, certificats générés pour validation). Chaque étape majeure doit produire une preuve vérifiable.

---

## 4. Logique des Scripts Partagés (`scripts/core/`)

Les scripts du socle commun sont conçus pour être idempotents dans la mesure du possible, ou du moins répétables sans effets de bord destructeurs. Ils suivent un flux séquentiel strict :

1. **`01-prerequisites.sh` :** Installation des outils locaux (`cfssl`, `kubectl`) sur la machine de l'utilisateur ou la jumpbox.
2. **`02-pki.sh` :** Génération de la Certificate Authority (CA) et de tous les certificats clients/serveurs en utilisant `cfssl`. Les adresses IP nécessaires (ex: SANs pour l'API server) sont injectées dynamiquement depuis l'inventaire.
3. **`03-kubeconfigs.sh` :** Création des fichiers `kubeconfig` pour le `kube-proxy`, le `kube-controller-manager`, le `kube-scheduler`, et l'utilisateur `admin`.
4. **`04-encryption-config.sh` :** Génération de la clé de chiffrement et du fichier `encryption-config.yaml` pour etcd.
5. **`05-etcd.sh` :** Distribution des binaires et certificats, puis configuration du service `etcd` sur le nœud `server`.
6. **`06-control-plane.sh` :** Distribution des binaires, certificats, et configuration des services `kube-apiserver`, `kube-controller-manager`, et `kube-scheduler` sur le nœud `server`. Configuration du RBAC pour l'autorisation Kubelet.
7. **`07-workers.sh` :** Distribution des binaires (runc, containerd, kubelet, kube-proxy), certificats, configuration CNI basique, et démarrage des services sur `node-0` et `node-1`.
8. **`08-kubectl-remote.sh` :** Configuration du client `kubectl` local pour interagir avec le cluster distant.
9. **`09-network-routes.sh` :** (Optionnel/Spécifique) Configuration des routes réseau pour le Pod CIDR si le provider ne le gère pas nativement via un CNI avancé.
10. **`10-dns.sh` :** Déploiement de CoreDNS dans le cluster.
11. **`11-smoke-tests.sh` :** Exécution d'une suite de tests (chiffrement, déploiement, port-forwarding, logs, exec).

---

## 5. Logique Terraform (`terraform/`)

Les modules Terraform de chaque provider doivent respecter une structure minimale commune :

- `main.tf` : Point d'entrée, déclaration du provider et des ressources principales.
- `variables.tf` : Définition des variables d'entrée (Région, Zone, Type d'instance).
- `outputs.tf` : Déclaration des sorties (Adresses IP publiques, IP privées).
- `network.tf` : Création du VPC, Subnets, et Firewall/Security Groups.
- `compute.tf` : Création des instances (Jumpbox, Server, Workers).
- `inventory.tmpl` : Template (utilisant la fonction `templatefile`) pour générer le fichier `inventory.env`.

**Principe clé :** Le code Terraform doit s'exécuter avec un minimum de variables obligatoires (idéalement zéro, en utilisant des valeurs par défaut raisonnables pour un lab).

---

## 6. Logique des Variables

Les variables sont gérées à deux niveaux :

1. **Variables d'Infrastructure (Terraform) :** Gérées via les fichiers `terraform.tfvars` (non versionnés) ou les valeurs par défaut dans `variables.tf`. Elles contrôlent la taille des instances, la région, etc.
2. **Variables d'Environnement d'Exécution (Scripts Core) :** Centralisées dans le fichier `inventories/<provider>/inventory.env`. Ce fichier est sourcé (`source inventory.env`) au début de chaque script du socle commun.

**Exemple de contenu attendu pour `inventory.env` :**

```bash
# Provider Info
PROVIDER="gcp"
REGION="europe-west1"
ZONE="europe-west1-b"

# Public IPs (pour l'accès SSH depuis l'extérieur)
JUMPBOX_PUBLIC_IP="34.123.45.67"
SERVER_PUBLIC_IP="34.123.45.68" # Optionnel, selon le design d'accès à l'API

# Private IPs (pour la communication interne du cluster)
SERVER_PRIVATE_IP="10.240.0.11"
NODE_0_PRIVATE_IP="10.240.0.20"
NODE_1_PRIVATE_IP="10.240.0.21"

# CIDRs
POD_CIDR="10.200.0.0/16"
SERVICE_CIDR="10.32.0.0/24"
```

---

## 7. Modèle d'Exécution

Le modèle d'exécution suit le cycle de vie suivant :

1. **Provisioning (Provider) :** L'utilisateur se place dans `terraform/<provider>/`, exécute `terraform init` puis `terraform apply`.
2. **Préparation (Jumpbox) :** L'utilisateur se connecte à la `jumpbox` via SSH (les clés SSH ayant été provisionnées par Terraform).
3. **Exécution Core (Jumpbox) :** L'utilisateur clone le dépôt sur la `jumpbox` (ou synchronise les scripts), source le fichier `inventory.env` (généré à l'étape 1), et exécute séquentiellement les scripts `01-*.sh` à `10-*.sh`.
4. **Validation (Local ou Jumpbox) :** L'utilisateur exécute le script `11-smoke-tests.sh` pour valider le cluster.
5. **Cleanup (Provider) :** L'utilisateur retourne dans `terraform/<provider>/` et exécute `terraform destroy` pour supprimer les ressources.

---

## 8. Logique d'Injection IP / Hostnames

La génération des certificats (PKI) est l'étape la plus sensible aux adresses IP. Le script `02-pki.sh` utilise les variables du fichier `inventory.env` pour injecter dynamiquement les adresses IP requises dans les fichiers CSR (Certificate Signing Request) JSON de `cfssl`.

Par exemple, le certificat de l'API Server (`server.pem`) doit inclure dans ses Subject Alternative Names (SANs) :
- L'adresse IP privée du nœud `server` (`SERVER_PRIVATE_IP`).
- L'adresse IP publique du nœud `server` (si l'API est exposée publiquement).
- L'adresse IP interne du service Kubernetes (ex: `10.32.0.1`, première IP du `SERVICE_CIDR`).
- Les noms DNS internes (`kubernetes`, `kubernetes.default`, etc.).
- Le hostname local (`server`).

Cette injection dynamique garantit que les certificats sont valides quel que soit le plan d'adressage IP choisi par le provider.

---

## 9. Gestion des Preuves d'Exécution

La collecte de preuves est automatisée dans les scripts Core. Chaque script, en cas de succès, génère un fichier de trace dans le répertoire `evidence/`.

Exemples de preuves collectées :
- `evidence/pki-validation.txt` : Sortie de la commande `openssl x509 -in ca.pem -text -noout` prouvant la validité de la CA.
- `evidence/etcd-health.txt` : Résultat de la commande `etcdctl endpoint health`.
- `evidence/nodes-ready.txt` : Sortie de `kubectl get nodes -o wide` montrant les nœuds en statut `Ready`.
- `evidence/smoke-tests-results.txt` : Journal d'exécution complet du script de validation.

Ces fichiers servent de garantie de la viabilité de l'architecture et de la procédure.

---

## 10. Stratégie de Validation

La validation (Smoke Tests) s'assure que toutes les fonctionnalités fondamentales du cluster sont opérationnelles. La suite de tests comprend :

1. **Chiffrement au repos :** Création d'un Secret, lecture directe dans etcd via `etcdctl`, et vérification que le contenu est chiffré (présence du préfixe `k8s:enc:aescbc:v1:`).
2. **Déploiement (Deployments) :** Création d'un Deployment Nginx, vérification du passage à l'état `Running` des pods, et validation de la répartition sur les nœuds `node-0` et `node-1`.
3. **Redirection de ports (Port Forwarding) :** Exécution de `kubectl port-forward` vers un pod Nginx et vérification de la réponse HTTP 200 via `curl`.
4. **Accès aux Logs :** Exécution de `kubectl logs` sur un pod pour valider la communication entre l'API Server, le Kubelet et le runtime containerd.
5. **Exécution de commandes (Exec) :** Exécution de `kubectl exec` dans un pod (ex: `nginx -v`) pour valider les flux interactifs.
6. **Services (NodePort/ClusterIP) :** Création d'un Service, et vérification de la joignabilité via le `kube-proxy`.

---

## 11. Trajectoire d'Évolution

Ce LLD global décrit l'état de la **V1** (déploiement manuel complet). La conception modulaire permet d'envisager sereinement les itérations futures :

- **V2 (Automatisation) :** Les scripts du répertoire `scripts/core/` seront traduits en rôles Ansible. L'inventaire dynamique généré par Terraform sera directement consommé par Ansible. La logique d'injection des IP et la structure des certificats resteront identiques.
- **V3 (Haute Disponibilité) :** La topologie logique évoluera pour inclure plusieurs nœuds `server` (ex: `server-0`, `server-1`, `server-2`) et un composant Load Balancer (ex: HAProxy ou Load Balancer Cloud natif). Le LLD global sera mis à jour pour refléter cette nouvelle topologie, et les scripts d'injection IP (SANs) seront adaptés pour inclure l'IP du Load Balancer.

---
**Signé :**
*Zidane Djamal*
*Architecte technique senior*
