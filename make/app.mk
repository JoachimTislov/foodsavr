.PHONY: run-dev run-prod build-apk-debug build-apk-release install-dev install-prod dev-chrome-prod dev-chrome build-web serve-web watch build 
DOTENV_FLAGS := $(shell [ -f .env ] && echo "--dart-define-from-file=.env")
FLUTTER_INSTALL := flutter install
FLUTTER_RUN_CMD := flutter run --no-pub $(DOTENV_FLAGS)
# dev:integration_test is ignored when doing a release build - https://github.com/flutter/flutter/issues/169336
FLUTTER_BUILD_APK_CMD := flutter build apk $(DOTENV_FLAGS)
CHECK_HASH_CMD := find lib test packages pubspec.yaml analysis_options.yaml -type f -not -path "*/.dart_tool/*" -not -name pubspec.lock 2>/dev/null | sort | xargs sha256sum | sha256sum | awk '{print $$1}'


run-dev: deps start-firebase-emulators ## Run the app with emulators
	@$(FLUTTER_RUN_CMD) --flavor development

run-prod: deps ## Run the production flavor
	@$(FLUTTER_RUN_CMD) --flavor production

build-apk-debug: deps ## Build a debug APK
	@$(FLUTTER_BUILD_APK_CMD) --flavor development --debug

build-apk-release: deps ## Build a release APK
	@$(FLUTTER_BUILD_APK_CMD) --flavor production --release

install-dev:
	@$(FLUTTER_INSTALL) --flavor development

install-prod:
	@$(FLUTTER_INSTALL) --flavor production

dev-chrome-prod: deps
	@$(FLUTTER_RUN_CMD) -d chrome --flavor production

dev-chrome: deps start-firebase-emulators ## Run the app in Chrome with emulators
	@$(FLUTTER_RUN_CMD) -d chrome

BASE_HREF ?= /
build-web: deps ## Build the web app
	@echo "Building web (base-href $(BASE_HREF))..."
	@flutter create . --platforms web
	@flutter build web --release --base-href "$(BASE_HREF)"

serve-web: build-web ## Serve the web app
	@echo "Serving build/web at http://localhost:8080 ..."
	@cd build/web && python3 -m http.server 8080

deps:

.deps-stamp: pubspec.yaml pubspec.lock
	@echo "Getting dependencies..."
	@flutter pub get > /dev/null
	@touch

watch:
	@dart run build_runner watch -d

build:
	@dart run build_runner build --delete-conflicting-outputs
