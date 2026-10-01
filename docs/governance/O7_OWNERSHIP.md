# O7 — Ownership Multicloud

## Propriétaire

`kubernetes-the-hard-way-multicloud` porte uniquement les différences d'infrastructure nécessaires pour instancier une topologie KTHW sur plusieurs providers.

### OWNED
- Terraform AWS ;
- Terraform Azure ;
- Terraform GCP ;
- Terraform IBM Cloud ;
- inventories provider ;
- scripts provision/cleanup provider ;
- LLD provider et comparaison de portabilité.

### CONSUMED
- internals Kubernetes : `kubernetes-the-hard-way-vagrant-architect-v29` ;
- cluster lifecycle industriel : `k8s-openshift-cluster-factory` ;
- services partagés : `shared-platform-services-openshift`.

### LEGACY_REFERENCE
- `docs/core/` ;
- `docs/onprem-vagrant/rebuild-kit/`.

Ces copies historiques ne doivent plus évoluer comme un second core Kubernetes.
