# Preuves d'Exécution (Evidence)

**Auteur :** Zidane Djamal

## Le rôle du dossier `evidence/`
Dans le cadre de l'apprentissage et de la validation d'une architecture d'infrastructure, il est crucial de conserver des traces prouvant que le déploiement a été réalisé avec succès. Le répertoire `evidence/` a pour vocation de stocker les résultats des commandes clés (logs, sorties de terminaux, captures d'écran éventuelles) générés lors des tests de validation (Chapitre 09 - Smoke Tests).

Ces preuves servent à :
1. **Valider le succès :** Démontrer que l'architecture décrite dans les HLD/LLD fonctionne réellement sur le provider ciblé.
2. **Faciliter le débogage :** Comparer les sorties attendues avec les sorties réelles en cas de comportement inattendu lors de futurs déploiements.
3. **Auditer l'infrastructure :** Conserver un historique de l'état du cluster à un instant T (version de Kubernetes, statut des nœuds, configuration réseau).

## Convention de nommage
Pour maintenir ce répertoire organisé et exploitable, tous les fichiers de preuves doivent respecter la convention de nommage suivante :

```text
<YYYYMMDD>-<provider>-<composant>-<type_de_test>.<extension>
```

**Exemples :**
- `20260322-gcp-cluster-nodes_status.txt`
- `20260322-aws-etcd-encryption_check.txt`
- `20260322-azure-network-pod_routing.log`

## Quels types de preuves stocker ?
Vous devez systématiquement stocker les sorties des commandes exécutées lors du Chapitre 09 (Smoke Tests). Voici les éléments essentiels :

1. **Statut des nœuds :** Sortie de `kubectl get nodes -o wide` (prouve que les workers sont `Ready` et que le Container Runtime est opérationnel).
2. **Santé des composants :** Sortie de `kubectl get componentstatuses` (prouve que le Control Plane est sain).
3. **Chiffrement au repos :** Sortie de la commande `etcdctl get /registry/secrets/... | hexdump -C` (prouve que les données sensibles sont chiffrées).
4. **Routage réseau :** Sortie du test `curl` sur le NodePort (prouve que le `kube-proxy` et le routage inter-nœuds de l'infrastructure fonctionnent).
5. **DNS du cluster :** Sortie d'un test de résolution DNS depuis un pod (ex: `kubectl exec -ti busybox -- nslookup kubernetes.default`).

## Comment relier les preuves à un contexte spécifique ?
Chaque fichier de preuve (texte ou log) doit commencer par un en-tête (header) indiquant le contexte exact de l'exécution. Cela garantit que la preuve reste exploitable même si elle est lue hors contexte.

**Format d'en-tête recommandé :**
```text
=== EVIDENCE LOG ===
Date: 2026-03-22
Provider: AWS (eu-west-1)
Kubernetes Version: v1.29.2
Executor: Zidane Djamal
Command: kubectl get nodes -o wide
====================
<sortie de la commande>
```

## Bonnes pratiques pour garder les preuves lisibles et exploitables
- **Format texte privilégié :** Privilégiez les fichiers `.txt` ou `.log` générés par redirection de commande (ex: `kubectl get nodes > evidence/...txt`) plutôt que des captures d'écran (`.png`), car le texte est indexable, copiable et versionnable efficacement par Git.
- **Nettoyage des données sensibles :** Assurez-vous de masquer ou de remplacer toute information sensible (mots de passe, tokens d'API, adresses IP publiques réelles si vous ne souhaitez pas les exposer) avant de commiter les fichiers dans ce dépôt.
- **Organisation par sous-dossiers :** Si le nombre de preuves devient important, créez des sous-dossiers par provider (ex: `evidence/gcp/`, `evidence/aws/`).
- **Ne commitez pas de binaires lourds :** Ne stockez pas de dumps de base de données complets ou de fichiers de logs de plusieurs mégaoctets. Conservez uniquement les extraits pertinents prouvant le succès du test.
