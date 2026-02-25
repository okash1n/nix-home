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
	@echo "[info] setup-mcp は廃止されました。ok-mcp-toggle を使用してください。"
	./agent-skills/ok-mcp-toggle/scripts/mcp_toggle.sh list
	@echo "[hint] 例1: ./agent-skills/ok-mcp-toggle/scripts/mcp_toggle.sh enable --scope project"
	@echo "[hint] 例2: ./agent-skills/ok-mcp-toggle/scripts/mcp_toggle.sh add box --preset box --scope project"

secret:
	./scripts/set-sops-env.sh
