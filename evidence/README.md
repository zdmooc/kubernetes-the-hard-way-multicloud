# Evidence — Multicloud

Ce dossier définit la convention de preuves provider.

## Statut actuel

**AUCUNE PREUVE RUNTIME CLOUD ACTUELLE N'EST REVENDIQUÉE.**

Les exemples historiques de noms de fichiers ou de commandes ne prouvent pas qu'un provider a été provisionné. Tant qu'un run réel n'est pas observé, chaque provider reste `NOT_PROVEN`.

## Convention future

Une preuve provider doit indiquer au minimum :
- date UTC ;
- provider / région ;
- commit Git ;
- versions Terraform/provider ;
- commande exécutée ;
- résultat `terraform init/validate/plan/apply` selon le niveau revendiqué ;
- inventory généré ;
- preuves Kubernetes uniquement si le core a réellement été exécuté.

Format recommandé :

```text
<YYYYMMDD>-<provider>-<gate>.<txt|log>
```

Avant commit, retirer tout credential, token, secret, clé privée, kubeconfig sensible ou donnée cloud non nécessaire.

Voir `CLAIM_EVIDENCE_MATRIX.md`.
