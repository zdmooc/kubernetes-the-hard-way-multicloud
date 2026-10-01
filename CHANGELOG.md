# Changelog

## O7 — 2026-10-01
- Recentrage sur les adapters IaaS AWS/Azure/GCP/IBM Cloud et la portabilité provider.
- Le core Kubernetes est désormais consommé depuis `kubernetes-the-hard-way-vagrant-architect-v29`.
- `docs/core/` et le rebuild kit on-prem sont classés `LEGACY_REFERENCE`.
- Suppression d'une copie exacte du document de référence Kubernetes.
- Remplacement du smoke check `componentstatuses` déprécié par `/readyz` et `/livez`.
- Ajout d'une CI GitHub statique avec Terraform fmt/validate sur quatre providers.
- Terraform remis au format.
- AWS : ingress administratif durci via `admin_cidr` obligatoire.
- Azure/GCP/IBM Cloud : ingress historique à requalifier avant tout apply réel.
- README providers alignés sur les fichiers réellement présents.
- Aucun provider cloud n'est revendiqué comme exécuté.
