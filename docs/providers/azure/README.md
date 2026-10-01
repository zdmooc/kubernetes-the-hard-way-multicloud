# Provider adapter — Azure

## Rôle

Cet adapter prépare l'IaaS Azure et l'inventaire pour le parcours KTHW canonique.

## Fichiers réels

- `terraform/azure/main.tf`
- `terraform/azure/variables.tf`
- `terraform/azure/versions.tf`
- `terraform/azure/outputs.tf`
- `terraform/azure/inventory.tpl`

## Spécificités

- Resource Group, VNet, subnet et NSG ;
- NIC et Public IP par VM ;
- `enable_ip_forwarding = true` sur les workers ;
- UDR vers les Pod CIDR ;
- génération de `inventories/azure/inventory.env`.

## Sécurité O7

Les règles historiques SSH/API restent à restreindre avant tout apply réel. Classification : `REQUALIFICATION_REQUIRED`.

## Validation

```bash
cd terraform/azure
terraform init -backend=false
terraform fmt -check
terraform validate
```

Aucun `terraform apply` Azure n'est revendiqué par O7.
