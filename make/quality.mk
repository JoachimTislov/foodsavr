.PHONY: check _run-checks analyze fmt fix test clean locales locale-check locale-clean generate-locales 
# Code quality commands
check:
	+@CURRENT_HASH=$$($(CHECK_HASH_CMD)); \
	if [ -f .check.sha256 ] && [ "$$CURRENT_HASH" = "$$(cat .check.sha256)" ]; then \
		echo "Code matches cached check. Skipping duplicate checks..."; \
	else \
		python3 scripts/ci/local_ci.py --make-check "$(MAKE)" || exit 1; \
		echo "All checks passed! Caching result..."; \
		$(CHECK_HASH_CMD) > .check.sha256; \
	fi

_run-checks: analyze test locale-check fix fmt

analyze: deps
	@echo "Running Flutter analyze..."
	@flutter analyze --fatal-infos --fatal-warnings --no-pub

fmt:
	@echo "Formatting Dart code..."
	@dart format .

fix: deps
	@echo "Fixing Dart code issues..."
	@dart fix --apply

test: deps
	@echo "Checking for Dart file changes in local commits or staged changes..."
	@FILES=$$(git --no-pager diff --name-only @{upstream}..HEAD;git --no-pager diff --name-only --staged; git --no-pager diff); \
	if echo "$$FILES" | grep -E '\.dart$$' > /dev/null; then \
		echo "Running tests..."; \
		flutter test --no-pub $(DOTENV_FLAGS); \
	else \
		echo "No Dart changes detected in local commits or staged changes. Skipping tests."; \
	fi

clean:
	@echo "Cleaning build artifacts..."
	@flutter clean
	@rm .deps-stamp .check.sha256 2>/dev/null || true

locales:
	@echo "Extracting locales..."
	@grep -r -o -E "'.*?'\.tr\(\)" lib/

locale-check: deps
	@echo "Checking localization keys..."
	@dart run scripts/locale/check_localizations.dart

locale-clean: deps
	@echo "Removing unused localization keys..."
	@dart run scripts/locale/remove_unused_locales.dart

generate-locales: deps
	@echo "Generating localization stubs..."
	@dart run scripts/locale/generate_localizations.dart
