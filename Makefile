.PHONY: help lint deploy sync-images store-secrets

help:
	@echo "Targets:"
	@echo "  make lint              — YAML + shellcheck"
	@echo "  make deploy            — Deploy controller + router"
	@echo "  make sync-images       — Mirror upstream images to Harbor"
	@echo "  make store-secrets     — Extract k8s secrets to AKV"

lint:
	shellcheck scripts/*.sh
	@if command -v yamllint >/dev/null 2>&1; then yamllint -c .yamllint.yml .; else echo "yamllint not installed (skip)"; fi

deploy:
	scripts/deploy.sh

sync-images:
	scripts/sync_images.sh

store-secrets:
	scripts/store_secrets.sh
