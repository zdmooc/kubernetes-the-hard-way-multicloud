# ==============================================================================
# Kubernetes The Hard Way - Multi-Cloud
# Makefile
# ==============================================================================

.PHONY: help tree lint-docs validate-structure show-roadmap

help: ## Affiche cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

tree: ## Affiche l'arborescence du projet (nécessite l'outil 'tree')
	@tree -I '.git|.terraform|*.tfstate*|certs|kubeconfigs'

lint-docs: ## Vérifie la syntaxe des fichiers Markdown (nécessite markdownlint)
	@echo "Vérification des fichiers Markdown..."
	@if command -v markdownlint >/dev/null 2>&1; then \
		markdownlint '**/*.md' --ignore node_modules; \
	else \
		echo "⚠️ markdownlint n'est pas installé. Ignoré."; \
	fi

validate-structure: ## Vérifie que les répertoires obligatoires existent
	@echo "Vérification de la structure du projet..."
	@test -d docs/hld || (echo "❌ docs/hld manquant" && exit 1)
	@test -d docs/lld || (echo "❌ docs/lld manquant" && exit 1)
	@test -d docs/core || (echo "❌ docs/core manquant" && exit 1)
	@test -d terraform/gcp || (echo "❌ terraform/gcp manquant" && exit 1)
	@test -d scripts/shared || (echo "❌ scripts/shared manquant" && exit 1)
	@echo "✅ Structure valide."

show-roadmap: ## Affiche la roadmap du projet depuis le README
	@grep -A 10 "## Roadmap" README.md || echo "Roadmap non trouvée."
