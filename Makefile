SHELL := /bin/bash

# ホスト名解決 (init.sh lines 460-466 と同等)
HOSTNAME_SHORT := $(shell hostname -s 2>/dev/null || hostname)
HOST_CONFIG := hosts/darwin/$(HOSTNAME_SHORT).nix
TARGET := $(if $(wildcard $(HOST_CONFIG)),$(HOSTNAME_SHORT),default)
NIX_HOME_USERNAME ?= $(shell id -un)

.PHONY: init check build switch update mcp secret

init:
	./scripts/init.sh

check:
	./scripts/check.sh

build:
	NIX_HOME_USERNAME="$(NIX_HOME_USERNAME)" darwin-rebuild build --impure --flake .#$(TARGET)

switch:
	sudo NIX_HOME_USERNAME="$(NIX_HOME_USERNAME)" darwin-rebuild switch --impure --flake .#$(TARGET)

update:
	nix flake update
	$(MAKE) build
	$(MAKE) switch

mcp:
	@SOPS_ENV="$$HOME/.config/sops-nix/secrets/rendered/sops-env.sh"; \
	if [ -f "$$SOPS_ENV" ]; then \
		. "$$SOPS_ENV"; \
	fi; \
	./scripts/setup-claude-mcp.sh; \
	./scripts/setup-codex-mcp.sh; \
	./scripts/setup-gemini-mcp.sh

secret:
	./scripts/set-sops-env.sh
