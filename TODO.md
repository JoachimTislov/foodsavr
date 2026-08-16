# TODO

## remaining prototype tasks

- [ ] "firestore.rules" best practices Flutter app
- [ ] "firestore.indexes.json" composite indexes guide

## packages to consider

- [ ] url_launcher
- [ ] lints
- [ ] dart_code_metrics: Advanced linter
- [ ] font_awesome
- [ ] timezone
- [ ] analyzer

## Testing Checklist (after #3)
- [-] Verify Material 3 theme in light and dark modes
- [-] Test pull-to-refresh functionality

notes:
- Delete, edit and add is not functional
- Sign out is not available all of the time 
- Layout should be default to dashboard view (to be implemented)
    - rather use navbar (dashboard, inventory, shopping lists, meal plan)
- shopping list is a unique collection with simple add/remove product functionality (read product with extra quantity)
- need to add a toggle in settings to switch between light/dark mode for testing
    - Shopping list routes to Collections with my inventory and shopping list

## Environment & Setup
- [ ] Create orchestrator skill to manage subagents and coordinate complex tasks
- [ ] Create orchestrator command (e.g., in `.gemini/commands/`) to trigger the orchestrator skill
- [ ] Create .gemini/commands folder with .toml files for custom commands and templates
    - [ ] Screenshot of page for reference to give better context to the LLM when adjusting UI
        - [ ] UI healing, grading in terms of user feeling, accessibility, material 3 compliance, etc.
    - [ ] Locales command
    - [ ] Code cleanup command for refactoring and improving code quality
    - [ ] Grep command for searching through codebase for specific patterns or issues
- [ ] Reference files inside of commands for better context and more specific adjustments
    - [ ] decide what should always be loaded into memory
- [ ] Add skills, rules and MCPs
- [ ] Consider TDD approach

## Firebase & Emulator
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
- [ ] Ensure widgets handle missing user docs gracefully.

## Features & Functionality
- [ ] Scanning products to ease the process of adding items to the inventory.
    - [ ] QR code
    - [ ] Picture ? (need to explore ML options for this)
- [ ] Add support for push/app/internal notifications (e.g., expiring products, meal plan reminders).
-  [ ] Transfer products between inventories
- [ ] Statistics and insights on inventory usage, waste reduction, etc.
- [ ] Support export/import (CSV/JSON) for user inventory.
- [ ] Support sharing meal plans and shopping lists with other users (e.g., family members).
    - [ ] Create shared (family/group) collections
- [ ] Support registering and tracking non-retail items (e.g., homemade meals, bulk items) with custom names and optional expiry.
    - [ ] Register unique product through scanning - creating picture and searching for product....

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
    - [ ] Implement user profile management (view/edit profile, change password, pass real user.avatarUrl once profile is loaded, implement deleteAccount)
- [ ] UI to list/add/edit products from the global catalog and user inventory.
    - [ ] Navigate to add product screen from product list
    - [ ] Navigate to edit screen from product list and product details
    - [ ] Show delete confirmation in product list and product details
- [ ] Implement LocationService for transfer management view (replace mock locations)
- [ ] Support max 3 different inventories (e.g., home, cabin, etc.) and allow users to switch between them.
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
- [ ] Write localization script to ensure all keys exists
- [ ] Add end-to-end (E2E) tests for critical user flows.
    - onboarding, adding inventory items, creating meal plans, etc.
- [ ] Set up GitHub Actions CI workflows for platform-specific build & run tests (when mature enough to justify emulator CI time):
    - [ ] Web CI: Install Node/Java/Flutter, start Firebase Emulators, run `flutter build web`, and execute headless Chrome integration tests.
    - [ ] Android CI: Run on `macos-latest` (for hardware virtualization), build APK, spin up Android Emulator via `reactivecircus/android-emulator-runner`, start Firebase Emulators, and run integration tests.

## Tempting integrations
- [ ] Implement error logging and monitoring (e.g., Sentry integration).
- [ ] Integrate with Rema (Æ), Coop Mega (Coop Member) and Trumf (Norwegian Group), Storebox and similar for automatic receipt scanning and inventory updates.
    - [ ] Support manual uploading of receipts (e.g., via image or CSV) to extract purchase data and automatically update inventory.
    - [Helpful openai overview](https://gist.github.com/HelgeSverre/80a7f34f874336324184a0c513c2e6a2)

## Commercialization & Next Steps
- [ ] Choose and implement a "Source Available" license (e.g., PolyForm Noncommercial or BSL 1.1) to prevent unauthorized financial benefit by third parties.
- [ ] create a new firestore project or setup a backend for production use
    Firestore specific:
    - [ ] read flutter, android/ios/web platform specific and firebase launch todo lists
    - [ ] use a support email
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
