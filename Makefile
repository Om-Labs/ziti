.PHONY: help lint deploy deploy-metallb sync-images store-secrets configure-services create-identities patch-coredns install-tunnel

help:
	@echo "Targets:"
	@echo "  make lint                — YAML + shellcheck"
	@echo "  make deploy              — Deploy controller + router"
	@echo "  make deploy-metallb      — Install MetalLB + IP pool"
	@echo "  make sync-images         — Mirror upstream images to Harbor"
	@echo "  make store-secrets       — Extract k8s secrets to AKV"
	@echo "  make configure-services  — Create Ziti services + policies"
	@echo "  make create-identities   — Create employee identities (NAMES='a b')"
	@echo "  make patch-coredns       — Add service hostnames to CoreDNS"
	@echo "  make install-tunnel      — Install ziti-tunnel systemd service (sudo)"

lint:
	shellcheck scripts/*.sh
	@if command -v yamllint >/dev/null 2>&1; then yamllint -c .yamllint.yml .; else echo "yamllint not installed (skip)"; fi

deploy:
	scripts/deploy.sh

deploy-metallb:
	scripts/deploy_metallb.sh

sync-images:
	scripts/sync_images.sh

store-secrets:
	scripts/store_secrets.sh

configure-services:
	scripts/configure_services.sh

create-identities:
	scripts/create_identities.sh $(NAMES)

patch-coredns:
	scripts/patch_coredns.sh

install-tunnel:
	sudo scripts/install_tunnel_service.sh
