.PHONY: dev start-firebase-emulators kill-firebase-emulators

dev-chrome: start-firebase-emulators
	@flutter run -d chrome

dev-android: start-firebase-emulators
	@flutter run -d android

start-firebase-emulators:
	@if ! lsof -ti :9099 -sTCP:LISTEN; then \
		firebase emulators:start > /dev/null 2>&1 & \
	fi

kill-firebase-emulators:
	@if lsof -ti :9099 -sTCP:LISTEN; then \
		echo "Killing Firebase Emulators..."; \
		lsof -ti :9099 -sTCP:LISTEN | xargs kill -9; \
	else \
		echo "No Firebase Emulators running"; \
	fi
