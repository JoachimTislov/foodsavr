# TODO

## Environment & Setup
- [x] Install Flutter SDK (^3.10.7) and run `make get` to fetch dependencies.
- [x] Create `assets/.env` with `ENVIRONMENT=development` and test credentials.
- [x] Ensure `lib/firebase_options.dart` is generated via `flutterfire configure` for project `my-foodsavr-store`.

## Firebase & Emulator
- [x] Install Firebase CLI (`npm i -g firebase-tools`) and log in.
- [x] Configure `firebase.json` with emulators for Auth (9099) and Firestore (8080).
- [ ] Start emulators with `firebase emulators:start`.
- [ ] Seed emulated data (users, products, meal plans) via `SeedingService`.
- [ ] Keep Firestore security rules in sync and validate against the emulator.

## Data Model & Collections
- [ ] Users collection `/users/{userId}` with fields `email`, `name`, `role`; ensure creation on first auth.
- [ ] Products/global catalog collection for shared items; align model with `product_model.dart`.
- [ ] Meal plans under `/users/{userId}/meal-plans/{mealPlanId}` referencing meals/recipes per docs.

## App Wiring
- [x] Removed in-memory repositories - now using Firestore with emulators in development.
- [x] Service locator connects to emulators when `ENVIRONMENT=development`.
- [ ] Ensure widgets handle missing user docs gracefully.

## UX & Flows
- [ ] Add UI to list/add/edit products from the global catalog and user inventory.
- [ ] Add meal plan creation/editing UI that consumes meals/recipes and surfaces upcoming expirations.
- [ ] Confirm auth flow fetches or creates a user document on login.

## Testing & CI
- [ ] Add emulator-backed integration tests for Auth and Firestore CRUD across users/products/meal plans.
- [ ] Run `make analyze` and `make test`; add emulator startup to CI before tests.
