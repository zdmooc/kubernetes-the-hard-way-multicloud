# Kubernetes The Hard Way — Vagrant On-Prem Rebuild Kit Complet

Ce kit permet de reconstruire la plateforme Kubernetes The Hard Way Vagrant après :

```bash
vagrant destroy -f
vagrant up
```

Contenu :
- scripts shell de A à Z
- manifests YAML
- runbook complet
- diagrammes Mermaid
- correctifs appliqués pendant le lab
- collecte d'evidence finale
- plan de commit Git

Topologie :
- jumpbox : 192.168.56.10
- controller-0 : 192.168.56.11
- controller-1 : 192.168.56.12
- controller-2 : 192.168.56.13
- worker-0 : 192.168.56.21
- worker-1 : 192.168.56.22
- API DNS : kubernetes.local
- Pod CIDR : 10.200.0.0/16
- Service CIDR : 10.32.0.0/24
- DNS Service : 10.32.0.10
