.PHONY: task feature research resolve-comments unit-tests integration-tests analyze-architecture 
task:
	@if [ -z "$(msg)" ]; then \
		echo "Error: Provide a msg argument (e.g., make task msg='implement auth flow')"; \
		exit 1; \
	fi
	@echo "Injecting INDEX.md context and starting task..."
	@gemini "Review the codebase index below to map out your strategy, then complete this task: $(msg). \n\n=== INDEX.md ===\n$$(cat INDEX.md)"

feature:
	@if [ -z "$(name)" ]; then \
		echo "Error: Provide a feature name (e.g., make feature name=shopping_list)"; \
		exit 1; \
	fi
	@echo "Scaffolding feature: $(name)..."
	@gemini -p "Activate the 'flutter-standards' skill and scaffold a new feature named '$(name)' following the 3-tier Layered Architecture (lib/models, lib/interfaces, lib/repositories, lib/services, lib/views)."

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
	gemini -p "Use the resolve-pr-comments skill for PR #$$PR_NUM."

unit-tests: deps
	@echo "Running unit tests..."
	@flutter test --no-pub || (flutter test --no-pub 2>&1 | gemini -p "Analyze the following unit test failures. Identify the root cause relative to the 3-tier Layered Architecture and suggest or apply fixes that maintain architectural integrity and Material 3 standards:")

integration-tests: deps start-firebase-emulators
	@echo "Running integration tests..."
	@flutter test integration_test --no-pub || (flutter test integration_test --no-pub 2>&1 | gemini -p "Analyze the following integration test failures. Ensure the Firebase emulators are properly utilized and that the tests align with the 3-tier Layered Architecture and Material 3 design patterns. Suggest or apply fixes:")

analyze-architecture: deps
	@echo "Analyzing architecture and code quality..."
	@flutter analyze --no-pub 2>&1 | gemini -p "Perform a deep architectural analysis of the codebase based on the provided lint issues and file structure. Focus on violations of the 3-tier Layered Architecture (lib/models, lib/interfaces, lib/repositories, lib/services, lib/views) and Material 3 design patterns. Provide a metadata report and fix the identified issues while ensuring generational consistency."
