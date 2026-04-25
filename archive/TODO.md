# Completed Tasks Archive

## UI
- [x] move local emulators toggle to login screen
- [x] expand "continue as guest" button
- [x] Handle guest logins in settings by either omit or adapting content
- [x] do not render empty string fields, e.g. description
- [x] avoid duplicate low value info/displayment...
- [x] remove top navbar, migrate/integrate actions in the pages, if any
- [x] NEVER have arrows on the right in cards (remove them all)
    - replace them with elevation or subtle border highlights
- [x] add an overview page all products registered/related to a user
    - need to figure out / design a good overview/dashboard. Add quick action to view all, probably just reimplement the View all link in dashboard.

## General
- [x] Seed database when using Firebase emulator for testing and development.
    - Added `make seed` target and `tool/seed_database.dart` script.

## Implemented packages
- [x] injectable
- [x] injectable_generator

## Testing Checklist (after #3)
- [x] Test with Firebase emulator running
- [x] Verify user-specific filtering (products shown only for logged-in user)
- [x] Test all three view modes (compact, normal, details)
- [x] Test product detail view navigation
- [x] Test collection listing and detail views
- [x] Verify expiration status indicators work correctly
- [x] Test delete confirmation dialog
- [x] Verify empty states display correctly

### Actions
- [x] move edit and delete icons (allow sign out and setting to always be present)
- [x] omit icons for product category and consider omitting mapping of product to categories
- [x] 0d -> Today
- [x] <0d -> Expired
- [x] move expiration warning text to tooltip and only show icon, warning 6>3 days before expiration, expired products should be clearly marked as expired
- [x] replace checked with info and align the warning with title
- [x] consider omitting or replacing the banner with icon
- [x] omit owner ID in product details view
- [x] figure out dates and expiration date relationship, a product can have quantity and expiration date, but they are not necessarily linked (e.g., I can have 2 cans of beans that expire on different dates)
    - [x] map expiration date to quantity, e.g., 2 cans of beans expiring on 2024-01-01 and 3 cans expiring on 2024-02-01

## Environment & Setup
- [x] Install Flutter SDK (^3.10.7) and run `make get` to fetch dependencies.
- [x] Create `assets/.env` with `ENVIRONMENT=development` and test credentials.
- [x] Ensure `lib/firebase_options.dart` is generated via `flutterfire configure` for project `my-foodsavr-store`.
- [x] Create .gemini/commands folder with .toml files for custom commands and templates
    - [x] Iteration command for fixing issues in flutter analyze until no issues remain
        - [x] Also one for Test, should be template
    - [x] Research command for fetching and presenting data from the internet safely

## Firebase & Emulator
- [x] Install Firebase CLI (`npm i -g firebase-tools`) and log in.
- [x] Configure `firebase.json` with emulators for Auth (9099) and Firestore (8080).
- [x] Start emulators with `firebase emulators:start`.
- [x] Seed emulated data (users, products, meal plans) via `SeedingService`.

## App Wiring
- [x] Removed in-memory repositories - now using Firestore with emulators in development.
- [x] Service locator connects to emulators when `ENVIRONMENT=development`.

## Features & Functionality
- [x] Barcode

## Testing & CI
- [x] Run `make analyze` and `make test`; add emulator startup to CI before tests. (#3)
