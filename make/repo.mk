.PHONY: hooks ci-local preflight worktree agent-sessions push 
hooks: ## Install Git hooks
	@git config core.hooksPath .githooks
	@echo "pre-push hook installed: runs scripts/ci/local_ci.py"

ci-local: ## Run local CI checks
	@python3 scripts/ci/local_ci.py

preflight:
	@echo "Running preflight sync checks..."
	@git fetch --quiet
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "Preflight failed: working tree is not clean."; \
		exit 1; \
	fi
	@if git rev-parse --verify @{upstream} >/dev/null 2>&1; then \
		if [ "$$(git rev-list --left-right --count @{upstream}...HEAD | awk '{print $$1}')" -ne 0 ]; then \
			echo "Preflight failed: branch is behind upstream. Pull/rebase first."; \
			exit 1; \
		fi \
	else \
		echo "No upstream branch found, skipping behind check."; \
	fi

worktree: ## Create a worktree (name=<issue>)
	@if [ -z "$(name)" ]; then \
		echo "Error: Provide a branch name or issue number (e.g., make worktree name=123)"; \
		exit 1; \
	fi
	@bash scripts/create_worktree.sh "$(name)" "$(dir)" "$(task)"

agent-sessions:
	@scripts/agents/agentctl sessions $(ARGS)

# Original targets
push: deps preflight ## Check and push the current branch
	@if git rev-parse --verify @{upstream} >/dev/null 2>&1; then \
		CHANGED=$$(git --no-pager diff --name-only @{upstream}..HEAD); \
	else \
		CHANGED=$$(git --no-pager diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null || true); \
	fi; \
	DI_PATTERN='^lib/(services|interfaces|repositories|di)/|^lib/(service_locator|injection)\.dart$$'; \
	if echo "$$CHANGED" | grep -qE "$$DI_PATTERN"; then \
		echo "Upstream DI changes detected, running dependency injection..."; \
		$(MAKE) di || { echo "dependency injection failed, aborting push."; exit 1; }; \
	fi
	@$(MAKE) check
	@if [ -n "$$(git status --short)" ]; then \
		echo "Error: Uncommitted formatting or linting changes detected after 'make check'."; \
		echo "Please include these changes in your commit before pushing."; \
		exit 1; \
	fi
	@echo "Pushing to remote..."
	@if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then \
		git push -u origin $$(git rev-parse --abbrev-ref HEAD); \
	else \
		git push; \
	fi
