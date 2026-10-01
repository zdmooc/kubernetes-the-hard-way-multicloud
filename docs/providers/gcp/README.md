# Provider adapter — GCP

## Rôle

Cet adapter prépare l'IaaS GCP et l'inventaire pour le parcours KTHW canonique.

## Fichiers réels

- `terraform/gcp/main.tf`
- `terraform/gcp/variables.tf`
- `terraform/gcp/versions.tf`
- `terraform/gcp/outputs.tf`
- `terraform/gcp/inventory.tpl`

## Spécificités

- VPC/subnetwork ;
- Compute Engine ;
- `can_ip_forward = true` sur les workers ;
- routes statiques Pod CIDR ;
- génération de `inventories/gcp/inventory.env`.

## Sécurité O7

La règle externe historique autorise encore l'administration depuis `0.0.0.0/0`. Elle doit être restreinte avant tout apply réel. Classification : `REQUALIFICATION_REQUIRED`.

## Validation

```bash
cd terraform/gcp
terraform init -backend=false
terraform fmt -check
terraform validate
```

`project_id` est requis lors d'un plan/apply. Aucun apply GCP n'est revendiqué par O7.
