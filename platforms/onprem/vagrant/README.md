# On-Prem local avec Vagrant

## Objectif
Simuler un environnement on-prem local pour exécuter Kubernetes The Hard Way sans cloud public.

## Topologie
- jumpbox : 192.168.56.10
- controller-0 : 192.168.56.11
- controller-1 : 192.168.56.12
- controller-2 : 192.168.56.13
- worker-0 : 192.168.56.21
- worker-1 : 192.168.56.22

## Pré-requis
- Vagrant
- VirtualBox
- au moins 16 Go RAM recommandés pour tout lancer

## Commandes
```bash
cd platforms/onprem/vagrant
vagrant up
vagrant status
vagrant ssh jumpbox
```

## Flux recommandé
1. lancer les VM
2. générer `inventory.env`
3. vérifier connectivité et résolution
4. brancher ensuite les étapes `core`
