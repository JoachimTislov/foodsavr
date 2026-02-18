# TODO

## Testing Checklist (after #3)
- [x] Test with Firebase emulator running
- [x] Verify user-specific filtering (products shown only for logged-in user)
- [x] Test all three view modes (compact, normal, details)
- [x] Test product detail view navigation
- [x] Test collection listing and detail views
- [x] Verify expiration status indicators work correctly
- [x] Test delete confirmation dialog
- [-] Verify Material 3 theme in light and dark modes
- [-] Test pull-to-refresh functionality
- [x] Verify empty states display correctly

notes:
- Delete, edit and add is not functional
- Sign out is not available all of the time 
- Layout should be default to dashboard view (to be implemented)
    - rather use navbar (dashboard, inventory, shopping lists, meal plan)
- shopping list is a unique collection with simple add/remove product functionality (read product with extra quantity)
- need to add a toggle in settings to switch between light/dark mode for testing
    - Shopping list routes to Collections with my inventory and shopping list

actions:
- move edit and delete icons (allow sigout and setting to always be present)
- omit icons for product category and consider omiting maping of product to catories
- 0d -> Today
- <0d -> Expired
- move expiration warning text to tooltip and only show icon, warning 6>3 days before expiration, expired products should be clearly marked as expired
 - replace checked with info and align the warning with title
 - consider omitting or replacing the banner with icon
- omit owner ID in product details view
- figure out dates and expiration date relationship, a product can have quantity and expiration date, but they are not necessarily linked (e.g., I can have 2 cans of beans that expire on different dates)
    - map expiration date to quantity, e.g., 2 cans of beans expiring on 2024-01-01 and 3 cans expiring on 2024-02-01

## Environment & Setup
- [x] Install Flutter SDK (^3.10.7) and run `make get` to fetch dependencies.
- [x] Create `assets/.env` with `ENVIRONMENT=development` and test credentials.
- [x] Ensure `lib/firebase_options.dart` is generated via `flutterfire configure` for project `my-foodsavr-store`.
- [x] Create .gemini/commands folder with .toml files for custom commands and templates
    - [x] Iteration command for fixing issues in flutter analyze until no issues remain
        - [x] Also one for Test, should be template
    - [ ] Screenshot of page for reference to give better context to the LLM when adjusting UI
        - [ ] UI healing, grading in terms of user feeling, accessibility, material 3 compliance, etc.
- [ ] Reference files inside of commands for better context and more specific adjustments
    - [ ] decide what should always be loaded into memory
- [ ] Add skills, rules and MCPs
- [ ] Consider TDD approach

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
    - global products shall not be editable by users, only admins can add/remove products from the global catalog
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
-  [ ] Transfer products between inventories
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
- [ ] Extend auth flow
    - [ ] third-party auth providers (Google and Facebook, etc.)
    - [ ] Reset / forgot password flow (via email or phone?)
    - [ ] Implement email verification flow after registration.
    - [ ] support guest users (optional, for trying out the app without registration)
    - [ ] Implement user profile management (view/edit profile, change password, etc.)
- [ ] Support max 3 different inventories (e.g., home, cabin, etc.) and allow users to switch between them.
- [ ] UI to list/add/edit products from the global catalog and user inventory.
- [ ] meal plan creation/editing UI that consumes meals/recipes and surfaces upcoming expirations.
- [ ] Settings page
    - [ ] Multi-language support and language switcher UI.
    - [ ] Theme selection (light/dark/system) and toggle in settings.
- [ ] Implement onboarding flow with welcome screen, auth options, and basic profile setup.
- [ ] Implement generative UI (should be done after meal plan CRUD is working)
- [ ] Ensure accessibility and screen reader support is in place for all views.
- [ ] Implement user feedback/reporting mechanism in-app.
    - [ ] crash reporting and error analytics.

## Testing & CI
- [ ] Add emulator-backed integration tests for Auth and Firestore CRUD
- [x] Run `make analyze` and `make test`; add emulator startup to CI before tests. (#3)
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
