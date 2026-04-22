# Plan d’intégration dans le dépôt `kubernetes-the-hard-way-multicloud`

## 1. Positionnement des fichiers déjà produits

### A. Concepts Kubernetes
Fichier source utilisateur : `kubernetes_concepts_v3_enrichi.md`

**Destination recommandée dans le dépôt :**
- `docs/reference/kubernetes-concepts-v3-enrichi.md`

**Pourquoi :**
- c’est un document de référence transverse
- il ne dépend pas d’un provider
- il sert de socle théorique avant les guides d’exécution

---

### B. Guide générique Hard Way – architecture / runbook
Fichier source utilisateur : `kubernetes_the_hard_way_guide_generique_architecte_a→z.md`

**Destination recommandée :**
- `docs/core/kubernetes-the-hard-way-guide-generique-architecte-a-z.md`

**Pourquoi :**
- ce document appartient au socle `core`
- il décrit la logique d’installation manuelle indépendante du provider

---

### C. Guide commandes / exécution brute
Fichier source utilisateur : `kubernetes_the_hard_way_guide_generique_architecte_a→z-coomandes.md`

**Destination recommandée :**
- `docs/core/kubernetes-the-hard-way-commandes-a-z.md`

**Pourquoi :**
- complète le guide précédent
- sert de runbook opératoire

---

### D. V6 spécialisation cloud & on-prem
Fichier source utilisateur : `kubernetes_v_6_specialisation_cloud_on_prem_a_partir_du_hard_way.md`

**Destination recommandée :**
- `docs/architecture/kubernetes-v6-specialisation-cloud-on-prem.md`

**Pourquoi :**
- c’est une couche d’architecture / mapping multi-environnement
- ce n’est ni du core d’installation ni un provider spécifique

---

## 2. Arborescence cible recommandée

```text
kubernetes-the-hard-way-multicloud/
├── docs/
│   ├── adr/
│   ├── architecture/
│   │   └── kubernetes-v6-specialisation-cloud-on-prem.md
│   ├── core/
│   │   ├── kubernetes-the-hard-way-guide-generique-architecte-a-z.md
│   │   └── kubernetes-the-hard-way-commandes-a-z.md
│   └── reference/
│       └── kubernetes-concepts-v3-enrichi.md
├── inventories/
│   └── onprem-vagrant.env.example
├── platforms/
│   └── onprem/
│       └── vagrant/
│           ├── Vagrantfile
│           ├── README.md
│           └── inventory.env.example
├── scripts/
│   └── onprem/
│       ├── prepare-hosts.sh
│       ├── generate-inventory.sh
│       └── collect-evidence.sh
└── evidence/
    └── onprem/
```

---

## 3. Stratégie Git recommandée

### Branche
Créer une branche dédiée :
```bash
git checkout -b feature/onprem-vagrant-foundation
```

### Commits recommandés
1. `docs: add core/reference/cloud documents produced from hard way work`
2. `feat(onprem): add vagrant foundation for local on-prem lab`
3. `feat(onprem): add inventory and helper scripts`
4. `docs(onprem): add readme and execution flow`

---

## 4. Ce qu’il faut faire ensuite dans le dépôt

### Priorité 1
Intégrer les 4 documents comme base documentaire du repo.

### Priorité 2
Créer le provider/lab On-Prem Vagrant comme environnement local d’apprentissage.

### Priorité 3
Faire produire à Vagrant un `inventory.env` compatible avec les futurs scripts `core`.

### Priorité 4
Ensuite seulement écrire `scripts/core/` en s’appuyant sur cet inventaire.

---

## 5. Décision d’architecture recommandée pour l’On-Prem local

Pour un vrai labo local simple et portable :
- **Vagrant + VirtualBox** en priorité
- ou **libvirt** si environnement Linux natif

### Pourquoi Vagrant d’abord
- simple à lancer sur poste Windows/Linux/macOS
- reproductible
- bon compromis pour un labo pédagogique
- proche d’un “on-prem simulé” sans dépendre d’un cloud public

### Topologie locale recommandée
- `jumpbox` : 192.168.56.10
- `controller-0` : 192.168.56.11
- `controller-1` : 192.168.56.12
- `controller-2` : 192.168.56.13
- `worker-0` : 192.168.56.21
- `worker-1` : 192.168.56.22

---

## 6. Règle importante
Ne pas commencer par tout automatiser. Il faut d’abord :
1. stabiliser l’environnement Vagrant
2. générer un inventaire fiable
3. vérifier SSH, IP, résolution, swap off, forwarding
4. seulement après brancher les scripts `core`
