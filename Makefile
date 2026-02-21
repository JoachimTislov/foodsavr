.PHONY: dev-chrome-prod dev-chrome dev-android start-firebase-emulators kill-firebase-emulators analyze fix fmt test test-auth-flow clean locales check check-fast check-full deps locale-check preflight push pr-comments-active pr-comments-resolve-active pr-comments-resolve-outdated

dev-chrome-prod:
	@flutter run -d chrome --no-pub --flavor production

dev-chrome: start-firebase-emulators
	@flutter run -d chrome --no-pub

dev-android: start-firebase-emulators
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

deps:
	@echo "Getting dependencies..."
	@flutter pub get

# Code quality commands
check: check-fast

check-fast: deps analyze fix fmt test locale-check

check-full: check-fast clean

analyze:
	@echo "Running Flutter analyze..."
	@flutter analyze --fatal-infos --fatal-warnings --no-pub

fmt:
	@echo "Formatting Dart code..."
	@dart format .

fix:
	@echo "Fixing Dart code issues..."
	@dart fix --apply

test:
	@echo "Running tests..."
	@flutter test --no-pub

test-auth-flow:
	@echo "Running auth flow regression test..."
	@flutter test --no-pub test/router_auth_flow_test.dart

clean:
	@echo "Cleaning build artifacts..."
	@flutter clean

locales:
	@echo "Extracting locales..."
	@grep -r -o -E "'.*?'\.tr\(\)" lib/

locale-check:
	@echo "Checking localization keys..."
	@dart run tool/check_localizations.dart

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

push: preflight
	@$(MAKE) check-full
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
