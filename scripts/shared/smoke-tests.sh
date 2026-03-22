#!/usr/bin/env bash
# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Script: smoke-tests.sh
# Description: Exécute les tests de validation de bout en bout
# Auteur: Zidane Djamal
# ==============================================================================

set -euo pipefail

echo "=== Lancement des Smoke Tests Kubernetes ==="

# 1. Vérification des nœuds
echo ">> Vérification du statut des nœuds..."
kubectl get nodes -o wide --kubeconfig admin.kubeconfig
echo ""

# 2. Vérification des composants
echo ">> Vérification des composants du Control Plane..."
kubectl get componentstatuses --kubeconfig admin.kubeconfig
echo ""

# 3. Test de déploiement
echo ">> Création d'un déploiement de test (nginx)..."
kubectl create deployment nginx --image=nginx:latest --kubeconfig admin.kubeconfig || true
kubectl wait --for=condition=available --timeout=60s deployment/nginx --kubeconfig admin.kubeconfig

# 4. Test d'exécution (exec)
echo ">> Test de la commande exec dans le pod..."
POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}" --kubeconfig admin.kubeconfig)
kubectl exec -ti $POD_NAME --kubeconfig admin.kubeconfig -- nginx -v
echo ""

# 5. Test d'exposition (Service)
echo ">> Exposition du déploiement via NodePort..."
kubectl expose deployment nginx --port 80 --type NodePort --kubeconfig admin.kubeconfig || true
NODE_PORT=$(kubectl get svc nginx -o jsonpath="{.spec.ports[0].nodePort}" --kubeconfig admin.kubeconfig)
echo "Service Nginx exposé sur le port: $NODE_PORT"
echo ""

echo "✅ Smoke Tests terminés. Pour valider le routage réseau, exécutez :"
echo "curl -I http://${NODE_0_PUBLIC_IP:-<NODE_0_IP>}:$NODE_PORT"
