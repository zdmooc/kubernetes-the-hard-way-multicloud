# O7 — Security findings

## Statut au 2026-10-01

### AWS — PARTIALLY_HARDENED

Les règles entrantes SSH, Kubernetes API et ICMP utilisent désormais `var.admin_cidr`.

- `admin_cidr` est obligatoire ;
- `0.0.0.0/0` est refusé par validation Terraform ;
- la règle egress reste volontairement ouverte pour le laboratoire.

Ce changement est uniquement **STATIC_VALIDATED** après CI. Aucun `terraform apply` AWS n'est revendiqué.

### Azure — REQUALIFICATION_REQUIRED

Le NSG historique accepte encore l'administration depuis une source globale dans les règles SSH/API.

Le durcissement automatique n'a pas été appliqué dans O7. Ne pas présenter cet overlay comme sécurisé pour un environnement persistant.

### GCP — REQUALIFICATION_REQUIRED

La règle externe historique autorise SSH/API depuis `0.0.0.0/0`.

Le texte historique indiquant que cela pouvait être acceptable pour un laboratoire ne constitue pas une recommandation de sécurité. L'overlay reste à restreindre avant tout apply réel.

### IBM Cloud — REQUALIFICATION_REQUIRED

Les règles entrantes historiques SSH/API/ICMP utilisent encore `0.0.0.0/0`.

Aucun apply réel n'est revendiqué.

## Règle de clôture O7

O7 peut valider la structure et la syntaxe statiques tout en conservant ces trois providers en `REQUALIFICATION_REQUIRED`.

Aucune preuve cloud runtime, HA ou production n'est créée par cette documentation.
