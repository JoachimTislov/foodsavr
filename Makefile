.PHONY: dev-chrome-prod dev-chrome dev-android start-firebase-emulators kill-firebase-emulators analyze fix fmt test clean locales check deps locale-check

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
check: analyze fix fmt test

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

clean:
	@echo "Cleaning build artifacts..."
	@flutter clean

locales:
	@echo "Extracting locales..."
	@grep -r -o -E "'.*?'\.tr\(\)" lib/

locale-check:
	@echo "Checking localization keys..."
	@dart run tool/check_localizations.dart
