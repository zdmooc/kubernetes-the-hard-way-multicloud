# Provider adapter — AWS

## Rôle

Cet adapter prépare l'infrastructure IaaS AWS et génère l'inventaire consommé par le parcours KTHW canonique.

Le core Kubernetes appartient à `zdmooc/kubernetes-the-hard-way-vagrant-architect-v29`.

## Fichiers réels

- `terraform/aws/main.tf`
- `terraform/aws/variables.tf`
- `terraform/aws/versions.tf`
- `terraform/aws/outputs.tf`
- `terraform/aws/inventory.tpl`

## Spécificités

- VPC/subnet/route table ;
- EC2 ;
- `source_dest_check = false` sur les workers pour le routage des Pod CIDR ;
- routes statiques vers les workers ;
- génération de `inventories/aws/inventory.env`.

## Sécurité O7

`admin_cidr` est obligatoire et ne peut pas être `0.0.0.0/0`. Il borne les règles entrantes SSH, Kubernetes API et ICMP.

Ne commiter ni credentials AWS ni clé privée SSH.

## Validation

```bash
cd terraform/aws
terraform init -backend=false
terraform fmt -check
terraform validate
terraform plan -var='admin_cidr=<votre-ip-publique>/32'
```

Le `plan` et l'`apply` ne sont pas revendiqués comme exécutés par O7. L'infrastructure reste `NOT_PROVEN` tant qu'une exécution réelle n'a pas été observée.
