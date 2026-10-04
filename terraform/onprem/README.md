# Terraform On-Prem / libvirt — D-095 design gate

**Status:** DESIGN_READY / NOT_IMPLEMENTED / RUNTIME_NOT_PROVEN  
**Owner:** provider/IaaS learning adapter  
**Industrial lifecycle owner:** `k8s-openshift-cluster-factory`

## Purpose

This directory reserves the future D-095 local private-infrastructure lab.

Target sequence:

```text
terraform fmt
-> terraform init
-> terraform validate
-> terraform plan
-> terraform apply
-> verify libvirt network/VMs
-> generate inventory
-> Linux/Kubernetes checks
-> evidence
-> terraform destroy
```

## Technology baseline

The intended provider is `dmacvicar/libvirt` 0.9.x. The provider underwent a major schema rewrite starting at 0.9.0, so implementation must follow the current official schema rather than copying legacy 0.8 examples.

## Planned resources

- libvirt network;
- storage pool/volumes;
- VM domains;
- cloud-init or equivalent first-boot configuration;
- generated inventory compatible with `inventories/onprem/inventory.env`.

## Gate

Do not add partial `.tf` files and mark them implemented unless:
1. `terraform fmt -check` passes;
2. `terraform init -backend=false` passes;
3. `terraform validate` passes;
4. the README states clearly whether apply/runtime is proven.

A static validation is not an apply proof.
