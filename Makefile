# Main entry points. Implementations live in make/*.mk; run `make help`.
.DEFAULT_GOAL := help

include make/app.mk
include make/setup.mk
include make/firebase.mk
include make/quality.mk
include make/repo.mk
include make/ai.mk
include scripts/github/github.mk

.PHONY: help
help:
	@echo "Main targets:"
	@echo "  run-dev / run-prod       Run the app (development / production flavor)"
	@echo "  dev-chrome               Run the app in Chrome with emulators"
	@echo "  build-apk-debug|release  Build an APK"
	@echo "  build-web / serve-web    Build / serve the web app"
	@echo "  check                    Analyze, format, test, locale-check"
	@echo "  test / analyze / fmt     Individual quality steps"
	@echo "  push                     Check and push the branch"
	@echo "  worktree name=<issue>    Create a worktree"
	@echo "  hooks                    Install the pre-push hook"
	@echo "  start-firebase-emulators / kill-firebase-emulators"
	@echo "  social-auth-setup, router-setup  One-time setup"
