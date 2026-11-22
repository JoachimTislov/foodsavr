.PHONY: firebase-options firebase-rules start-firebase-emulators kill-firebase-emulators view-emulator locale-seed rules-test remote-seed 
firebase-options:
	@base64 -w 0 lib/firebase_options.dart | gh secret set FIREBASE_OPTIONS_B64
	@base64 -w 0 lib/firebase_options.dart | gh secret set FIREBASE_OPTIONS_B64 --app dependabot

firebase-rules:
	@base64 -w 0 firestore.rules | gh secret set FIRESTORE_RULES_B64
	@base64 -w 0 firestore.rules | gh secret set FIRESTORE_RULES_B64 --app dependabot

start-firebase-emulators:
	@if ! lsof -ti :9099 -sTCP:LISTEN > /dev/null; then \
		echo "Starting Firebase Emulators..."; \
		firebase emulators:start --project demo-project > /tmp/firebase-emulators.log 2>&1 & \
		emu_pid=$$!; \
		for _ in $$(seq 1 120); do \
			if lsof -ti :8080 -sTCP:LISTEN > /dev/null && lsof -ti :9099 -sTCP:LISTEN > /dev/null; then \
				break; \
			fi; \
			if ! kill -0 $$emu_pid 2> /dev/null; then \
				echo "Firebase Emulator process exited during startup:" >&2; \
				tail -20 /tmp/firebase-emulators.log >&2; \
				exit 1; \
			fi; \
			sleep 1; \
		done; \
		if ! (lsof -ti :8080 -sTCP:LISTEN > /dev/null && lsof -ti :9099 -sTCP:LISTEN > /dev/null); then \
			echo "Firebase Emulators did not become ready within 120s:" >&2; \
			tail -20 /tmp/firebase-emulators.log >&2; \
			kill $$emu_pid 2> /dev/null || true; \
			exit 1; \
		fi; \
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

locale-seed: start-firebase-emulators
	@echo "Seeding local emulator data using standalone seeder..."
	@dart run scripts/seed_database.dart

rules-test: start-firebase-emulators
	@echo "Running Firestore security rules unit tests..."
	cd firestore-rules && npm ci && npx jest --ci

remote-seed:
	@if [ -z "$(env)" ]; then \
		echo "Error: Provide an environment file (e.g., make seed-remote env=seed-remote-creds.json)"; \
		exit 1; \
	fi
	@echo "Seeding remote database using config: $(env)..."
	@SEED_CONFIG_FILE=$(env) dart run scripts/seed_database.dart
