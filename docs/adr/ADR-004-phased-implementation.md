# ADR 004 : Implémentation en Phases Itératives

**Statut :** Accepté
**Date :** 22-03-2026
**Auteur :** Zidane Djamal

## Contexte

Construire une plateforme Kubernetes complète, multi-cloud, documentée, sécurisée, hautement disponible et automatisée représente un effort d'ingénierie colossal. Si le projet tente d'atteindre tous ces objectifs dès la première version, le risque d'enlisement (tunnel effect) est très élevé.

De plus, l'objectif principal du dépôt est pédagogique. Présenter d'emblée à un utilisateur un code Terraform complexe gérant des Load Balancers multi-zones, couplé à des playbooks Ansible gérant la rotation des certificats, noierait les concepts fondamentaux de Kubernetes sous une montagne d'outillage d'infrastructure et de configuration management.

Il est nécessaire de définir une stratégie de livraison qui permette de publier rapidement un actif fonctionnel tout en garantissant une trajectoire d'évolution claire vers l'industrialisation.

## Décision

Nous avons décidé d'adopter une stratégie d'implémentation itérative, découpée en phases (Versions) strictement délimitées. Chaque phase doit produire un dépôt fonctionnel, testable et documenté de bout en bout.

**Périmètre de la Phase 1 (V1 - La Fondation "Hard Way") :**
- Provisionnement d'infrastructure minimal (1 AZ, 1 Control Plane, 2 Workers).
- Exécution entièrement manuelle des étapes de configuration Kubernetes (via scripts bash didactiques).
- Sécurité basique (pas de HA, pas de RBAC avancé, pas de Service Mesh).
- Objectif : Compréhension profonde de la mécanique interne (PKI, etcd, kubelet).

**Trajectoire future définie :**
- **V2 (Automatisation) :** Remplacement des scripts bash manuels par des rôles Ansible idempotents, introduction d'une CI basique.
- **V3 (Haute Disponibilité) :** Évolution de la topologie (3 Control Planes, Load Balancers), etcd distribué.
- **V4 (Production Ready) :** Hardening sécurité (CIS Benchmarks), Observabilité (Prometheus/Grafana), GitOps (ArgoCD).

## Conséquences

### Conséquences positives
- **Livraison rapide de valeur :** La V1 peut être publiée, testée et utilisée rapidement par la communauté sans attendre des mois de développement.
- **Pédagogie progressive :** L'utilisateur peut commencer par la V1 pour comprendre le "comment ça marche", puis passer à la V2 pour apprendre "comment l'automatiser proprement".
- **Maîtrise de la complexité :** Les décisions architecturales complexes (choix d'un CNI avancé, stratégie de stockage persistant) sont reportées aux phases ultérieures, allégeant la charge cognitive initiale.
- **Gestion des attentes :** En documentant explicitement ce qui est "Hors Périmètre" dans la V1 (ex: la Haute Disponibilité), on évite les critiques sur le manque de maturité "production" de cette première itération.

### Conséquences négatives
- **Dette technique assumée :** Les scripts bash de la V1, bien que didactiques, ne sont pas conçus pour être maintenus sur le long terme. Ils constituent une dette technique volontaire qui sera remboursée par la réécriture en Ansible lors de la V2.
- **Refactoring d'infrastructure :** Le passage de la V1 (1 Control Plane) à la V3 (3 Control Planes + LB) nécessitera une réécriture significative des modules Terraform des 5 providers.

## Alternatives écartées

- **Approche "Big Bang" (Tout ou rien) :** Tenter de livrer un cluster HA, automatisé via Ansible, sur les 5 clouds dès le premier commit. Écarté en raison du risque d'échec, du délai de réalisation trop long, et de la perte de l'aspect pédagogique "step-by-step" fondamental au concept du "Hard Way".
- **Automatisation immédiate (Ansible en V1) :** Écarté. Bien que l'automatisation soit une bonne pratique d'ingénierie, elle masque les commandes sous-jacentes. L'utilisateur qui exécute un playbook Ansible ne voit pas la commande `cfssl` générer le certificat, ce qui est précisément ce que la V1 cherche à enseigner.
