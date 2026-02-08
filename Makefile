SHELL := /bin/bash

.PHONY: init
init:
	./scripts/init.sh

.PHONY: check
check:
	./scripts/check.sh
