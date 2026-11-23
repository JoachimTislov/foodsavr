# Main entry points. Implementations live in make/*.mk; run `make help`.
.DEFAULT_GOAL := help

include make/app.mk
include make/setup.mk
include make/firebase.mk
include make/quality.mk
include make/repo.mk
include make/ai.mk
include make/bypass.mk
include make/human.mk
include scripts/github/github.mk

.PHONY: help
help: ## List available commands
	@awk 'match($$0, /^[[:alnum:]_.-]+:[^#]*## /) {split($$0, entry, /:.*## /); printf "  %-27s %s\n", entry[1], entry[2]}' $(MAKEFILE_LIST)
