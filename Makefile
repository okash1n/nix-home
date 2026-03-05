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
	@if command -v npm >/dev/null 2>&1; then \
		npm update -g; \
	else \
		echo "[skip] npm is not installed; skipping npm update -g"; \
	fi
	@if command -v claude >/dev/null 2>&1; then \
		claude update; \
	else \
		echo "[skip] claude is not installed; skipping claude update"; \
	fi
	@BREW_BIN=""; \
	if command -v brew >/dev/null 2>&1; then \
		BREW_BIN="$$(command -v brew)"; \
	elif [ -x "/opt/homebrew/bin/brew" ]; then \
		BREW_BIN="/opt/homebrew/bin/brew"; \
	elif [ -x "/usr/local/bin/brew" ]; then \
		BREW_BIN="/usr/local/bin/brew"; \
	fi; \
	if [ -n "$$BREW_BIN" ]; then \
		"$$BREW_BIN" update && "$$BREW_BIN" upgrade; \
	else \
		echo "[skip] brew is not installed; skipping brew update/upgrade"; \
	fi
	$(MAKE) build
	$(MAKE) switch

mcp:
	@echo "[info] setup-mcp は廃止されました。ok-mcp-toggle を使用してください。"
	./agent-skills/ok-mcp-toggle/scripts/mcp_toggle.sh list
	@echo "[hint] 例1: ./agent-skills/ok-mcp-toggle/scripts/mcp_toggle.sh enable --scope project"
	@echo "[hint] 例2: ./agent-skills/ok-mcp-toggle/scripts/mcp_toggle.sh add box --preset box --scope project"

secret:
	./scripts/set-sops-env.sh
