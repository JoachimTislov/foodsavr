# TODO

## Testing Checklist (after #3)
- [ ] Test with Firebase emulator running
- [ ] Verify user-specific filtering (products shown only for logged-in user)
- [ ] Test all three view modes (compact, normal, details)
- [ ] Test product detail view navigation
- [ ] Test collection listing and detail views
- [ ] Verify expiration status indicators work correctly
- [ ] Test delete confirmation dialog
- [ ] Verify Material 3 theme in light and dark modes
- [ ] Test pull-to-refresh functionality
- [ ] Verify empty states display correctly

## Environment & Setup
- [x] Install Flutter SDK (^3.10.7) and run `make get` to fetch dependencies.
- [x] Create `assets/.env` with `ENVIRONMENT=development` and test credentials.
- [x] Ensure `lib/firebase_options.dart` is generated via `flutterfire configure` for project `my-foodsavr-store`.

## Firebase & Emulator
- [x] Install Firebase CLI (`npm i -g firebase-tools`) and log in.
- [x] Configure `firebase.json` with emulators for Auth (9099) and Firestore (8080).
- [x] Start emulators with `firebase emulators:start`.
- [x] Seed emulated data (users, products, meal plans) via `SeedingService`.
- [ ] Add offline support and sync for Firestore data.
- [ ] Keep Firestore security rules in sync and validate against the emulator.
    - [ ] Create the initial set of rules for users, products, inventory, shopping lists, and meal plans.

## Data Model & Collections
~- [ ] Users collection `/users/{userId}` with fields `email`, `name`, `role`; ensure creation on first auth.~
- [ ] Products/global catalog collection for shared items; align model with `product_model.dart`.
- [ ] User inventory collection `/users/{userId}/inventory` referencing global products with quantity/expiry.
- [ ] Shopping lists under `/users/{userId}/shopping-lists/{listId}` referencing products.
- [ ] Meal plans under `/users/{userId}/meal-plans/{mealPlanId}` referencing meals/recipes per docs.

## App Wiring
- [x] Removed in-memory repositories - now using Firestore with emulators in development.
- [x] Service locator connects to emulators when `ENVIRONMENT=development`.
- [ ] Ensure widgets handle missing user docs gracefully.

## Features & Functionality
- [ ] Scanning products to ease the process of adding items to the inventory.
    - [ ] Barcode
    - [ ] QR code
    - [ ] Picture ? (need to explore ML options for this)
- [ ] Add support for push/app/internal notifications (e.g., expiring products, meal plan reminders).
- [ ] Support export/import (CSV/JSON) for user inventory.
- [ ] Support sharing meal plans and shopping lists with other users (e.g., family members).
    - [ ] Create shared (family/group) collections

### LLM-dependent features
- [ ] Generate recipe ideas based on the user's current inventory.
- [ ] Provide suggestions on how to use ingredients before they expire.

## Admin users
- [ ] Approve or reject product additions to global registry
    - [ ] role-based access

## UX, Flows and Views
- [ ] UI to list/add/edit products from the global catalog and user inventory.
- [ ] meal plan creation/editing UI that consumes meals/recipes and surfaces upcoming expirations.
- [ ] Settings page
    - [ ] Multi-language support and language switcher UI.
- [ ] Implement onboarding flow with welcome screen, auth options, and basic profile setup.
- [ ] Extend auth flow to google sign-in, vipps integration, user profile management and new login view
    - [ ] Confirm auth flow fetches or creates a user document on login.
- [ ] Implement generative UI (should be done after meal plan CRUD is working)
- [ ] Ensure accessibility and screen reader support is in place for all views.
- [ ] Implement user feedback/reporting mechanism in-app.
    - [ ] crash reporting and error analytics.

## Testing & CI
- [ ] Add emulator-backed integration tests for Auth and Firestore CRUD
- [ ] Run `make analyze` and `make test`; add emulator startup to CI before tests.
- [ ] Write localization script to ensure all keys exists
- [ ] Add end-to-end (E2E) tests for critical user flows.
    - onboarding, adding inventory items, creating meal plans, etc.

## Tempting integrations
- [ ] Implement error logging and monitoring (e.g., Sentry integration).

## Commercialization & Next Steps
- [ ] Create company and legal entity for the app.
- [ ] Set up app store accounts (Apple Developer, Google Play Console).
- [ ] Branding and app icon design.
- [ ] Add changelog and versioning documentation.
- [ ] Deploy to Google play store (go through android release process)
- [ ] App Store and Play Store listing preparation (screenshots, descriptions, etc.)
- [ ] Vipps integration ?
- [ ] Payment integration: Vipps, Stripe, RevenueCat or similar for in-app purchases and subscriptions.
- [ ] Implement analytics (Firebase Analytics or similar) to track user engagement and feature usage.
- [ ] Automate app store deployment (CI/CD for Play Store/App Store).
