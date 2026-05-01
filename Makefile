.PHONY: all dev-chrome-prod dev-chrome dev-android start-firebase-emulators kill-firebase-emulators analyze fix fmt test clean locales check _run-checks deps di locale-check preflight push

all: check

DOTENV_FLAGS := $(shell [ -f .env ] && echo "--dart-define-from-file=.env")
FLUTTER_RUN_CMD := flutter run --no-pub $(DOTENV_FLAGS)
FLUTTER_BUILD_APK_CMD := flutter build apk --no-pub $(DOTENV_FLAGS)
CHECK_HASH_CMD := find lib test tool pubspec.yaml analysis_options.yaml Makefile -type f 2>/dev/null | sort | xargs sha256sum | sha256sum | awk '{print $$1}'

run-dev: deps start-firebase-emulators
	@$(FLUTTER_RUN_CMD) --flavor development

run-prod: deps
	@$(FLUTTER_RUN_CMD) --flavor production

build-apk-debug: deps
	@$(FLUTTER_BUILD_APK_CMD) --flavor development --debug

build-apk-release: deps
	@$(FLUTTER_BUILD_APK_CMD) --flavor production --release

dev-chrome-prod: deps
	@$(FLUTTER_RUN_CMD) -d chrome --flavor production

dev-chrome: deps start-firebase-emulators
	@$(FLUTTER_RUN_CMD) -d chrome

start-firebase-emulators:
	@if ! lsof -ti :9099 -sTCP:LISTEN > /dev/null; then \
		echo "Starting Firebase Emulators..."; \
		firebase emulators:start --project demo-project > /dev/null 2>&1 & \
		until lsof -ti :8080 -sTCP:LISTEN > /dev/null && lsof -ti :9099 -sTCP:LISTEN > /dev/null; do \
			sleep 1; \
		done; \
	else \
		echo "Firebase Emulators already running"; \
	fi

kill-firebase-emulators:
	@if lsof -t -i:8080 -i:9199 -i:9099 -sTCP:LISTEN > /dev/null; then \
		echo "Killing Firebase Emulators..."; \
		lsof -t -i:8080 -i:9199 -i:9099 -sTCP:LISTEN | xargs kill -9; \
	else \
		echo "No Firebase Emulators running"; \
	fi

deps: .deps-stamp

.deps-stamp: pubspec.yaml pubspec.lock
	@echo "Getting dependencies..."
	@flutter pub get > /dev/null
	@touch .deps-stamp

di:
	@dart run build_runner build --delete-conflicting-outputs

view-emulator:
	@echo "Opening Firebase Emulator UI in browser..."
	@# Note: Firebase Emulator Suite UI defaults to port 4000. Change the port below if needed.
	@if [ "$$(uname)" = "Darwin" ]; then \
		open http://localhost:8081; \
	elif [ "$$(uname)" = "Linux" ]; then \
		xdg-open http://localhost:8081; \
	else \
		start http://localhost:8081; \
	fi

# Code quality commands
check:
	@CURRENT_HASH=$$($(CHECK_HASH_CMD)); \
	if [ -f .check.sha256 ] && [ "$$CURRENT_HASH" = "$$(cat .check.sha256)" ]; then \
		echo "Code matches cached check. Skipping duplicate checks..."; \
	else \
		$(MAKE) _run-checks || exit 1; \
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
	@dart run tool/locale/check_localizations.dart

locale-clean: deps
	@echo "Removing unused localization keys..."
	@dart run tool/locale/remove_unused_locales.dart

generate-locales: deps
	@echo "Generating localization stubs..."
	@dart run tool/locale/generate_localizations.dart

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

worktree:
	@if [ -z "$(name)" ]; then \
		echo "Error: Provide a branch name or issue number (e.g., make worktree name=123)"; \
		exit 1; \
	fi
	@bash tool/create_worktree.sh "$(name)" "$(dir)" "$(task)"

migrate-test: start-firebase-emulators
	@echo "Running local database migrations..."
	@dart run tool/deploy/deploy_schema.dart

# --- Automation & Gemini Targets ---

.PHONY: data seed-local seed-remote task feature research resolve-comments unit-tests integration-tests analyze-architecture

task:
	@if [ -z "$(msg)" ]; then \
		echo "Error: Provide a msg argument (e.g., make task msg='implement auth flow')"; \
		exit 1; \
	fi
	@echo "Injecting INDEX.md context and starting task..."
	@gemini "Review the codebase index below to map out your strategy, then complete this task: $(msg). \n\n=== INDEX.md ===\n$$(cat INDEX.md)"

data: seed-local

seed-local: start-firebase-emulators
	@echo "Seeding local emulator data using standalone seeder..."
	@dart run tool/seed_database.dart

seed-remote:
	@if [ -z "$(env)" ]; then \
		echo "Error: Provide an environment file (e.g., make seed-remote env=seed-remote-creds.json)"; \
		exit 1; \
	fi
	@echo "Seeding remote database using config: $(env)..."
	@SEED_CONFIG_FILE=$(env) dart run tool/seed_database.dart

feature:
	@if [ -z "$(name)" ]; then \
		echo "Error: Provide a feature name (e.g., make feature name=shopping_list)"; \
		exit 1; \
	fi
	@echo "Scaffolding feature: $(name)..."
	@gemini -p "Activate the 'creation' skill and scaffold a new feature named '$(name)' following the 3-tier Layered Architecture (lib/models, lib/interfaces, lib/repositories, lib/services, lib/views)."

research:
	@if [ -z "$(topic)" ]; then \
		echo "Error: Provide a research topic (e.g., make research topic='Firebase Security Rules')"; \
		exit 1; \
	fi
	@echo "Conducting research on: $(topic)..."
	@gemini -p "Activate the 'research' skill and conduct structured research on the topic: '$(topic)'. Save the findings in the research/ directory following the project's research standards."

resolve-comments:
	@echo "Starting automated PR comment resolution..."
	@PR_NUM=$$(gh pr view --json number -q .number 2>/dev/null); \
	if [ -z "$$PR_NUM" ]; then \
		echo "Error: No active pull request found for this branch."; \
		exit 1; \
	fi; \
	gemini -p "/resolve $$PR_NUM"

unit-tests: deps
	@echo "Running unit tests..."
	@flutter test --no-pub || (flutter test --no-pub 2>&1 | gemini -p "Analyze the following unit test failures. Identify the root cause relative to the 3-tier Layered Architecture and suggest or apply fixes that maintain architectural integrity and Material 3 standards:")

integration-tests: deps start-firebase-emulators
	@echo "Running integration tests..."
	@flutter test integration_test --no-pub || (flutter test integration_test --no-pub 2>&1 | gemini -p "Analyze the following integration test failures. Ensure the Firebase emulators are properly utilized and that the tests align with the 3-tier Layered Architecture and Material 3 design patterns. Suggest or apply fixes:")

analyze-architecture: deps
	@echo "Analyzing architecture and code quality..."
	@flutter analyze --no-pub 2>&1 | gemini -p "Perform a deep architectural analysis of the codebase based on the provided lint issues and file structure. Focus on violations of the 3-tier Layered Architecture (lib/models, lib/interfaces, lib/repositories, lib/services, lib/views) and Material 3 design patterns. Provide a metadata report and fix the identified issues while ensuring generational consistency."

# Original targets
push: deps preflight
	@CHANGED=$$(git --no-pager diff --name-only @{upstream}..HEAD); \
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

include tool/github/github.mk

