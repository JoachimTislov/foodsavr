.PHONY: dev-chrome dev-android start-firebase-emulators kill-firebase-emulators analyze fmt test clean

dev-chrome: start-firebase-emulators
	@flutter run -d chrome

dev-android: start-firebase-emulators
	@flutter run -d android

start-firebase-emulators:
	@if ! lsof -ti :9099 -sTCP:LISTEN > /dev/null; then \
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

# Code quality commands
analyze:
	@echo "Running Flutter analyze..."
	@flutter analyze --fatal-infos --fatal-warnings

fmt:
	@echo "Formatting Dart code..."
	@dart format .

test:
	@echo "Running tests..."
	@flutter test

clean:
	@echo "Cleaning build artifacts..."
	@flutter clean
