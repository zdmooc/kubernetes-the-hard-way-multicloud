# Contribuer à Kubernetes The Hard Way - Multi-Cloud

Merci de l'intérêt que vous portez à ce projet ! Ce dépôt a une vocation pédagogique forte et suit une architecture stricte définie dans le dossier `docs/adr/`.

## Principes Fondamentaux

Avant de soumettre une contribution, assurez-vous de respecter les principes suivants :

1. **Séparation Core / Provider (ADR-001) :** Ne mélangez jamais du code d'infrastructure (Terraform) avec les scripts d'installation Kubernetes (bash).
2. **Topologie Standard (ADR-002) :** La topologie (jumpbox, server, node-0, node-1) est immuable en V1. N'ajoutez pas de code pour gérer un nombre dynamique de workers dans les scripts Core.
3. **Pédagogie avant tout :** Les scripts bash sont volontairement verbeux. N'essayez pas de les "optimiser" au point de les rendre illisibles pour un débutant.

## Processus de Contribution

### 1. Signaler un problème (Issue)
Si vous trouvez un bug (ex: une commande qui échoue sur un provider spécifique) ou une erreur dans la documentation, ouvrez une Issue en décrivant :
- Le provider concerné (GCP, AWS, Azure, IBM, On-Prem).
- L'étape exacte (ex: `docs/core/06-etcd.md`).
- Les logs d'erreur.

### 2. Créer une branche
- Forkez le dépôt.
- Créez une branche depuis `main`.
- Nommez votre branche de manière explicite : `fix/aws-routing`, `docs/typo-pki`, `feat/new-provider-scaleway`.

### 3. Conventions de Commit
Utilisez les [Conventional Commits](https://www.conventionalcommits.org/) :
- `feat:` : Ajout d'une nouvelle fonctionnalité (ex: nouveau provider).
- `fix:` : Correction d'un bug.
- `docs:` : Modification de la documentation uniquement.
- `chore:` : Maintenance (Makefile, gitignore, etc.).

### 4. Qualité Documentaire
Si vous modifiez un script `scripts/core/`, vous **devez** mettre à jour le fichier Markdown correspondant dans `docs/core/`. Le code et la documentation doivent toujours être parfaitement synchronisés.

### 5. Soumettre une Pull Request (PR)
- Décrivez clairement ce que votre PR modifie.
- Si votre PR modifie un provider existant, fournissez dans la PR une preuve (issue de `evidence/`) que le cluster se déploie toujours correctement avec votre modification.

## Ajout d'un nouveau Provider

Si vous souhaitez ajouter un nouveau fournisseur Cloud (ex: Scaleway, Oracle Cloud, DigitalOcean) :
1. Créez le dossier `terraform/<provider>/`.
2. Créez le dossier `docs/providers/<provider>/`.
3. Assurez-vous que votre code Terraform génère un fichier `inventory.env` parfaitement compatible avec le contrat d'interface.
4. Créez un LLD dans `docs/lld/<provider>.md`.

Merci pour votre contribution !

*Zidane Djamal*
