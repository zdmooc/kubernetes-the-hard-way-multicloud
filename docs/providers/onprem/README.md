# Provider Overlay : On-Premises

**Auteur :** Zidane Djamal  
**D-095 status:** REFERENCE / SCRIPT-ASSISTED / TERRAFORM ON-PREM NOT IMPLEMENTED / RUNTIME NOT PROVEN

## Rôle

L'overlay on-prem représente un environnement local ou de Cloud privé **sans imposer un fournisseur**. Dans l'état courant du dépôt, il sert de contrat pédagogique autour de quatre nœuds logiques (`jumpbox`, `server`, `node-0`, `node-1`) et d'un inventaire commun.

Le provisioning/lifecycle industriel des clusters reste la responsabilité de `k8s-openshift-cluster-factory`.

## État réel du dépôt

Présent aujourd'hui :
- `inventories/onprem/lab.env.example`;
- `scripts/onprem/prepare-hosts.sh`;
- `scripts/onprem/cleanup.sh`;
- `docs/lld/onprem.md`;
- un patrimoine Vagrant séparé dans `kubernetes-the-hard-way-vagrant-architect-v29`.

Absent aujourd'hui :
- implémentation Terraform `terraform/onprem/*.tf`;
- preuve `terraform plan/apply/destroy` sur libvirt/KVM;
- runtime VMware/vSphere, OpenStack ou Nutanix.

Toute ancienne description indiquant que `terraform/onprem/main.tf`, `network.tf`, `compute.tf` ou `cloud_init.tf` existaient déjà doit être considérée comme corrigée par ce document.

## Scénarios

### Scénario A — actuel / portable

VMs préparées hors du dépôt -> inventaire -> `prepare-hosts.sh` -> core pédagogique.

### Scénario B — D-095 cible future

Sur un hôte Linux compatible KVM/libvirt :

```text
Terraform
-> libvirt network/storage/VM
-> inventory
-> Linux preparation
-> Kubernetes core
-> evidence
-> terraform destroy
```

Le provider Terraform libvirt moderne est `dmacvicar/libvirt`. D-095 a vérifié la branche 0.9.x actuelle ; l'implémentation devra être validée contre la documentation officielle au moment du code.

## Pourquoi KVM/libvirt comme cible de lab

- accessible sans licence de Cloud privé propriétaire ;
- expose les concepts VM/network/storage ;
- permet de démontrer Terraform + virtualisation sur un hôte Linux ;
- ne crée aucun faux claim VMware/OpenStack/Nutanix.

## Environnement Windows / VirtualBox

VirtualBox/Vagrant reste un chemin valide pour démontrer :
- VM lifecycle local ;
- réseau privé ;
- Linux ;
- Ansible ;
- Kubernetes internals.

Il ne doit pas être présenté comme une preuve de Cloud privé d'entreprise.

## Contrat d'inventaire

Le fichier cible reste :
`inventories/onprem/inventory.env`

avec notamment :
- PROVIDER/REGION/ZONE ;
- IP jumpbox/server/node-0/node-1 ;
- Pod/Service CIDR ;
- SSH user/key.

## D-095 backlog

1. INFRA-2 : rejouer le lab Vagrant/Linux/Ansible dans le dépôt spécialiste.
2. INFRA-3 : implémenter `terraform/onprem/` uniquement sur un environnement Linux/libvirt compatible.
3. Capturer `fmt/init/validate/plan/apply/verify/destroy`.
4. Promouvoir le niveau de preuve seulement après observation.

## Truth boundary

```text
documentation = REFERENCE
scripts present = IMPLEMENTED
terraform/onprem = NOT_IMPLEMENTED
Vagrant replay = PENDING
KVM/libvirt apply = NOT_PROVEN
VMware/OpenStack/Nutanix = REFERENCE_ONLY
production private cloud = NOT_CLAIMED
```

Voir également `docs/lld/onprem.md` et `terraform/onprem/README.md`.
