.PHONY: dev-chrome-prod dev-chrome dev-android start-firebase-emulators kill-firebase-emulators analyze fix fmt test test-auth-flow clean locales check check-fast check-full deps locale-check generate-di preflight push pr-comments-active pr-comments-resolve-active pr-comments-resolve-outdated

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

# Code quality commands
check: deps analyze test locale-check

check-full: check fix fmt clean

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
	@echo "Running tests..."
	@flutter test --no-pub

test-auth-flow: deps
	@echo "Running auth flow regression test..."
	@flutter test --no-pub test/router_auth_flow_test.dart

clean:
	@echo "Cleaning build artifacts..."
	@flutter clean

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
	@if [ "$$(git rev-list --left-right --count @{upstream}...HEAD | awk '{print $$1}')" -ne 0 ]; then \
		echo "Preflight failed: branch is behind upstream. Pull/rebase first."; \
		exit 1; \
	fi

push: deps preflight
	@if git diff --quiet --exit-code lib/service_locator.dart lib/services/ lib/interfaces/ lib/repositories/ lib/di/ lib/injection.dart; then \
		echo "No DI changes detected, skipping generate-di."; \
	else \
		echo "DI changes detected, running generate-di..."; \
		$(MAKE) generate-di || { echo "generate-di failed, aborting push."; exit 1; }; \
	fi
	@$(MAKE) check-full
	@if [ -n "$$(git status --short)" ]; then \
		git add .; \
		git commit -m "format with dart"; \
		head -n 1 .git/COMMIT_EDITMSG | xargs -I{} echo {} >> .git-blame-ignore-revs; \
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
