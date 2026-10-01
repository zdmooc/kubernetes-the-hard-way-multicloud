# Provider adapter — IBM Cloud

## Rôle

Cet adapter prépare l'IaaS IBM Cloud VPC et l'inventaire pour le parcours KTHW canonique.

## Fichiers réels

- `terraform/ibmcloud/main.tf`
- `terraform/ibmcloud/variables.tf`
- `terraform/ibmcloud/versions.tf`
- `terraform/ibmcloud/outputs.tf`
- `terraform/ibmcloud/inventory.tpl`

## Spécificités

- VPC Gen2 et subnet ;
- Virtual Server Instances ;
- Floating IPs ;
- `allow_ip_spoofing = true` sur les workers ;
- custom routes Pod CIDR ;
- génération de `inventories/ibmcloud/inventory.env`.

## Secrets et sécurité

La clé API doit être injectée via `TF_VAR_ibmcloud_api_key` ou un mécanisme secret local et ne doit jamais être commitée.

Les règles entrantes historiques SSH/API/ICMP restent à restreindre avant tout apply réel. Classification : `REQUALIFICATION_REQUIRED`.

## Validation

```bash
cd terraform/ibmcloud
terraform init -backend=false
terraform fmt -check
terraform validate
```

Aucun apply IBM Cloud n'est revendiqué par O7.
