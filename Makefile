.PHONY: dev-chrome-prod dev-chrome dev-android start-firebase-emulators kill-firebase-emulators analyze fix fmt test clean locales check deps codegen locale-check generate-di preflight push

DOTENV_FLAGS := $(shell [ -f .env ] && echo "--dart-define-from-file=.env")

build-android: deps
	@flutter build apk --no-pub $(DOTENV_FLAGS)

dev-chrome-prod: deps
	@flutter run -d chrome --no-pub --flavor production $(DOTENV_FLAGS)

dev-chrome: deps start-firebase-emulators
	@flutter run -d chrome --no-pub $(DOTENV_FLAGS)

dev-android: deps start-firebase-emulators
	@flutter run -d android --no-pub $(DOTENV_FLAGS)

start-firebase-emulators:
	@if ! lsof -ti :9099 -sTCP:LISTEN > /dev/null; then \
		echo "Starting Firebase Emulators..."; \
		firebase emulators:start --project demo-project > /dev/null 2>&1 & \
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

codegen:
	@dart run build_runner build --delete-conflicting-outputs

# Code quality commands
check: analyze test locale-check fix fmt

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
	@rm .deps-stamp 2>/dev/null

locales:
	@echo "Extracting locales..."
	@grep -r -o -E "'.*?'\.tr\(\)" lib/

locale-check: deps
	@echo "Checking localization keys..."
	@dart run tool/check_localizations.dart

generate-di: deps
	@echo "Generating injectable code..."
	@dart run build_runner build --delete-conflicting-outputs

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

# --- Automation & Gemini Targets ---

.PHONY: data feature research resolve-comments unit-tests integration-tests analyze-architecture

data: start-firebase-emulators
	@echo "Seeding emulator data using standalone seeder..."
	@dart run tool/seed_database.dart

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
		echo "Upstream DI changes detected, running generate-di..."; \
		$(MAKE) generate-di || { echo "generate-di failed, aborting push."; exit 1; }; \
	fi
	@$(MAKE) check
	@if [ -n "$$(git status --short)" ]; then \
		git add .; \
		git commit -m "format with dart"; \
		git rev-parse HEAD >> .git-blame-ignore-revs; \
		git add .git-blame-ignore-revs; \
		git commit -m "add formatting changes to .git-blame-ignore-revs"; \
	fi
	@echo "Pushing to remote..."
	@if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then \
		git push -u origin $$(git rev-parse --abbrev-ref HEAD); \
	else \
		git push; \
	fi

