# Kubernetes The Hard Way — Multicloud Provider Adapters

## Statut O7

**PROVIDER PORTABILITY / TERRAFORM ADAPTER SPECIALIST — RUNTIME NOT PROVEN**

Rôle canonique :

> adapter une topologie de VM Kubernetes à plusieurs fournisseurs d'infrastructure sans recopier le core Kubernetes.

Ce dépôt est propriétaire de :
- Terraform AWS / Azure / GCP / IBM Cloud ;
- réseau, compute, firewall et paramètres propres à chaque provider ;
- génération d'inventaires ;
- scripts provider de provision/cleanup ;
- HLD/LLD de portabilité et différences provider.

Le core Kubernetes n'est plus propriétaire ici. Sa source canonique est :

`zdmooc/kubernetes-the-hard-way-vagrant-architect-v29`

Le dépôt Vagrant porte PKI, kubeconfigs, encryption-at-rest, etcd, control plane, workers, CNI, DNS, RBAC, systemd, diagnostic et smoke tests pédagogiques.

## Frontière avec Cluster Factory

`k8s-openshift-cluster-factory` reste le propriétaire du provisioning/lifecycle/Day-2 industriel des clusters.

Ce dépôt Multicloud reste un laboratoire de compréhension des **adapters IaaS autour de KTHW**, pas une seconde Cluster Factory.

## État de preuve

```text
Terraform/provider code present        = IMPLEMENTED
Static CI                              = STATIC_VALIDATED seulement après run vert observé
terraform plan/apply AWS              = NOT_PROVEN
terraform plan/apply Azure            = NOT_PROVEN
terraform plan/apply GCP              = NOT_PROVEN
terraform plan/apply IBM Cloud        = NOT_PROVEN
terraform on-prem/libvirt design       = DESIGN_READY / NOT_IMPLEMENTED
Kubernetes runtime on cloud providers = NOT_PROVEN
Production                            = NOT_CLAIMED
```

Les fichiers sous `docs/core/` et `docs/onprem-vagrant/rebuild-kit/` sont désormais **LEGACY_REFERENCE** : ils ne sont plus source de vérité et seront réduits progressivement lorsque les liens auront été migrés.

## Parcours

1. lire `docs/hld/HLD.md` et le LLD provider ;
2. choisir `terraform/<provider>/` ;
3. produire l'infrastructure et l'inventory ;
4. consommer le core pédagogique depuis le dépôt Vagrant ;
5. capturer les preuves provider dans `evidence/`.

## Evidence

Voir :
- `docs/governance/O7_OWNERSHIP.md`
- `evidence/CLAIM_EVIDENCE_MATRIX.md`
- `evidence/README.md`

Aucun provider cloud n'est annoncé comme exécuté tant qu'un run réel n'a pas été observé.


## D-095 Infrastructure convergence

For the Architecte Solutions Infrastructure track:
- public-cloud Terraform adapters remain reference/static assets;
- on-prem currently remains script-assisted;
- `terraform/onprem/README.md` defines the future libvirt/KVM implementation gate;
- no VMware/OpenStack/Nutanix runtime is claimed;
- Cluster Factory remains the industrial lifecycle owner.
