# Plan d’intégration O7 — Kubernetes The Hard Way Multicloud

## Décision actuelle

Ce dépôt ne doit plus intégrer ni maintenir une seconde copie du core Kubernetes.

Source canonique des internals Kubernetes :

`zdmooc/kubernetes-the-hard-way-vagrant-architect-v29`

Le présent dépôt reste spécialisé sur les adapters d’infrastructure et la portabilité provider.

## OWNED ici

- `terraform/aws/`
- `terraform/azure/`
- `terraform/gcp/`
- `terraform/ibmcloud/`
- inventories par provider
- scripts de provision/cleanup propres aux providers
- HLD/LLD et comparaisons de portabilité

## LEGACY_REFERENCE

- `docs/core/`
- `docs/onprem-vagrant/rebuild-kit/`

Ces répertoires restent temporairement présents pour préserver les références historiques, mais ne doivent plus recevoir de nouveau développement du core Kubernetes.

Le document dupliqué `docs/reference/kubernetes-concepts-v3-enrichi.md` a été retiré lors d’O7 ; sa copie canonique reste dans le dépôt Vagrant.

## Flux cible

```text
KTHW Vagrant
  PKI / etcd / control plane / workers / CNI / DNS / RBAC / systemd
            ^
            |
            | consumes
            |
KTHW Multicloud
  AWS / Azure / GCP / IBM Cloud adapters
  Terraform / networking / compute / inventories
```

Pour industrialiser le lifecycle cluster, utiliser `k8s-openshift-cluster-factory` et non ce dépôt.

## Règle de preuve

Un `terraform validate` ou un manifest présent ne prouve pas un `terraform apply`, un cluster fonctionnel, une HA réelle ou une exécution de production.
