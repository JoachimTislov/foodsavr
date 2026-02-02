.PHONY: help run-dev run-prod build-apk build-ios build-web test clean get analyze fmt

# Default target
help:
	@echo "Flutter Makefile Commands:"
	@echo "  help           - Display this help message."
	@echo "  run-dev        - Run the Flutter app in development mode."
	@echo "  run-prod       - Run the Flutter app in production mode."
	@echo "  build-apk      - Build an Android APK."
	@echo "  build-ios      - Build an iOS app."
	@echo "  build-web      - Build a web app."
	@echo "  test           - Run all Flutter tests."
	@echo "  clean          - Clean the Flutter project."
	@echo "  get            - Run flutter pub get."
	@echo "  analyze        - Run flutter analyze."
	@echo "  fmt            - Format Dart code."

run-dev:
	@echo "Running Flutter app in development mode..."
	@flutter run --flavor development

run-prod:
	@echo "Running Flutter app in production mode..."
	@flutter run --flavor production

build-apk:
	@echo "Building Android APK..."
	@flutter build apk

build-ios:
	@echo "Building iOS app..."
	@flutter build ios

build-web:
	@echo "Building Web app..."
	@flutter build web

test:
	@echo "Running Flutter tests..."
	@flutter test

clean:
	@echo "Cleaning Flutter project..."
	@flutter clean

get:
	@echo "Running flutter pub get..."
	@flutter pub get

analyze:
	@echo "Running flutter analyze..."
	@flutter analyze

fmt:
	@echo "Formatting Dart code..."
	@dart format lib
