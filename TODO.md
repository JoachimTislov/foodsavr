# TODO

Open work is tracked in GitHub issues. Start from the entrypoint epic:

- **#188 — Epic: Close current gaps (entrypoint, task list with sequenced, standalone PR-sized tasks)**

Other open epics/tracking issues:

- #158 — Epic: Eval & validation setup (remaining: #166, #168)
- #171 — Future: Go API server (ConnectRPC) + MCP adapter server

## remaining prototype tasks

- [ ] "firestore.indexes.json" composite indexes guide
- [ ] Firestore rules best-practices pass (rules are deliberately untracked; CI validates via `FIRESTORE_RULES_B64` secret — see #165/#185)

## packages to consider

- [ ] url_launcher
- [ ] lints
- [ ] dart_code_metrics: Advanced linter
- [ ] font_awesome
- [ ] timezone
- [ ] analyzer

## Firebase & Emulator

- [ ] Add offline support and sync for Firestore data.
- [ ] Keep the meal-plans and groups collections covered by the owner/group rules (see #196, #197).

## Features & Functionality

- [ ] Support for push/app/internal notifications — local expiry reminders tracked in #198.
- [ ] Statistics and insights on inventory usage, waste reduction, etc.
- [ ] Support export/import (CSV/JSON) for user inventory.
- [ ] Support registering and tracking non-retail items (e.g., homemade meals, bulk items) with custom names and optional expiry.

### LLM-dependent features

- [ ] Generate recipe ideas based on the user's current inventory.
- [ ] Provide suggestions on how to use ingredients before they expire.

## Admin users

- [ ] Approve or reject product additions to global registry
    - [ ] role-based access

## UX, Flows and Views

- [ ] Implement email verification flow after registration.
- [ ] Support guest users (optional, for trying out the app without registration).
- [ ] Implement user profile management (view/edit profile, change password, pass real user.avatarUrl once profile is loaded, implement deleteAccount).
- [ ] Implement LocationService for transfer management view (replace mock locations).
- [ ] Support max 3 different inventories (e.g., home, cabin, etc.) and allow users to switch between them.
- [ ] Implement onboarding flow with welcome screen, auth options, and basic profile setup.
- [ ] Implement generative UI (should be done after meal plan CRUD is working).
- [ ] Ensure accessibility and screen reader support is in place for all views.
- [ ] Implement user feedback/reporting mechanism in-app.
    - [ ] crash reporting and error analytics.

## Tempting integrations

- [ ] Implement error logging and monitoring (e.g., Sentry integration).
- [ ] Trumf and Storebox clients (Coop is tracked in #194; Rema is done).
- [ ] Register unique product through scanning — creating picture and searching for product.

## Commercialization & Next Steps

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
