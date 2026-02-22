.PHONY: dev-chrome-prod dev-chrome dev-android start-firebase-emulators kill-firebase-emulators analyze fix fmt test test-auth-flow clean locales check check-full deps locale-check generate-di preflight push pr-comments-active pr-comments-resolve-active pr-comments-resolve-outdated

dev-chrome-prod: deps
	@flutter run -d chrome --no-pub --flavor production

dev-chrome: deps start-firebase-emulators
	@flutter run -d chrome --no-pub

dev-android: deps start-firebase-emulators
	@flutter run -d android --no-pub

start-firebase-emulators:
	@if ! lsof -ti :9099 -sTCP:LISTEN > /dev/null; then \
		echo "Starting Firebase Emulators..."; \
		firebase emulators:start --project demo-project > /dev/null 2>&1 & \
	else \
		echo "Firebase Emulators already running"; \
	fi

kill-firebase-emulators:
	@if lsof -t -i:8080 -i:9199 -i:9099 > /dev/null; then \
		echo "Killing Firebase Emulators..."; \
		lsof -t -i:8080 -i:9199 -i:9099 | xargs kill -9; \
	else \
		echo "No Firebase Emulators running"; \
	fi

deps: .deps-stamp

.deps-stamp: pubspec.yaml pubspec.lock
	@echo "Getting dependencies..."
	@flutter pub get > /dev/null
	@touch .deps-stamp

# Code quality commands
check: deps analyze test locale-check

check-full: check fix fmt

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
		flutter test --no-pub; \
	else \
		echo "No Dart changes detected in local commits or staged changes. Skipping tests."; \
	fi

test-auth-flow: deps
	@echo "Running auth flow regression test..."
	@flutter test --no-pub test/router_auth_flow_test.dart

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
	@if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then \
		branch=$$(git rev-parse --abbrev-ref HEAD); \
		echo "Setting upstream to origin/$$branch"; \
		git branch --set-upstream-to=origin/$(git rev-parse --abbrev-ref HEAD); \
	else \
		echo "Upstream already set."; \
	fi
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
push: deps preflight
	@DI_FILES=$$(/usr/bin/ls lib/services/* lib/interfaces/* lib/repositories/* lib/di/*; echo lib/service_locator.dart lib/injection.dart); \
	CHANGED=$$(git --no-pager diff --name-only @{upstream}..HEAD); \
	if echo "$$CHANGED" | grep -qF "$$DI_FILES"; then \
		echo "Upstream DI changes detected, running generate-di..."; \
		$(MAKE) generate-di || { echo "generate-di failed, aborting push."; exit 1; }; \
	fi
	@$(MAKE) check-full
	@if [ -n "$$(git status --short)" ]; then \
		git add .; \
		git commit -m "format with dart"; \
		git rev-parse HEAD >> .git-blame-ignore-revs; \
		git commit -m "add formatting changes to .git-blame-ignore-revs" --amend --no-edit; \
	fi
	@echo "Pushing to remote..."
	@git push

pr-comments-active:
	@if [ -z "$(PR)" ]; then \
		echo "Usage: make pr-comments-active PR=<number>"; \
		exit 1; \
	fi
	@tool/list_active_review_threads.sh $(PR)

pr-comments-resolve-active:
	@if [ -z "$(PR)" ]; then \
		echo "Usage: make pr-comments-resolve-active PR=<number>"; \
		exit 1; \
	fi
	@tool/resolve_active_review_threads.sh $(PR)

pr-comments-resolve-outdated:
	@if [ -z "$(PR)" ]; then \
		echo "Usage: make pr-comments-resolve-outdated PR=<number>"; \
		exit 1; \
	fi
	@tool/resolve_outdated_review_threads.sh $(PR)
