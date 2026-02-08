SHELL := /bin/bash

.PHONY: init
init:
	./init.sh

.PHONY: check-unmanaged
check-unmanaged:
	./scripts/check-unmanaged.sh
