# Unified User & State Initialization

This document defines the standard for ensuring that a user's Firestore document and its required schema exist across all environments (Local Development, Remote Test, and Production).

## 1. Core Philosophy

To maintain **dev/prod parity**, the application is responsible for its own state initialization. We avoid "test-only" magic or manual seeding by default. If a user is authenticated via Firebase Auth but their corresponding Firestore document is missing, the application must automatically and explicitly initialize it using the standard `UserInitializationService`.

**Exception:** Complex data seeding (e.g., pre-populating a development inventory) is permitted in development and test environments ONLY if the `ENABLE_AUTO_SEED` flag is explicitly enabled. Use of this flag must be documented.

## 2. Implementation Strategy

Instead of hidden "guards" in sub-services, we use a centralized **`UserInitializationService`** that is called at the **authentication entry points**.

### Objectives
*   **Environment Parity:** The initialization logic is identical in all environments.
*   **Resiliency:** The app can self-heal if a user document is missing but the user is authenticated.
*   **Consistency:** All services can assume the `/users/{userId}` document exists.

## 3. Core Component: `UserInitializationService`

A dedicated service that handles the "First-Run" setup for any authenticated user.

*   **Path:** `lib/services/user_initialization_service.dart`
*   **Responsibilities:**
    *   `initializeUser(User user)`: Checks if `/users/{userId}` exists. If not, creates it with default data.
    *   `ensureDefaultCollections(String userId)`: Creates a default "Inventory" or "Shopping List" if needed.

## 4. Integration into `AuthService`

The `AuthService` is the primary orchestrator. Every successful sign-in or sign-up must trigger the initialization flow.

### Pattern: Explicit Post-Auth Init

```dart
// lib/services/auth_service.dart

@override
Future<UserCredential> signIn(...) async {
  final credential = await _firebaseAuth.signInWithEmailAndPassword(...);
  
  // 💡 Ensure Firestore state is ready BEFORE returning
  if (credential.user != null) {
    await _userInitService.initializeUser(credential.user!);
  }
  
  return credential;
}
```

## 5. Testing & Validation

### Integration Tests
1.  **Setup:** Clear the Firestore Emulator state.
2.  **Act:** Sign in with a test user.
3.  **Assert:** 
    *   The `/users/{userId}` document is created automatically.
    *   This same logic is verified as production-ready because it uses the exact same `UserInitializationService`.

## 6. Implementation Tasks

1.  **Service Creation:** Implement `UserInitializationService` with `getIt` registration.
2.  **Auth Integration:** Update `AuthService` methods (`signIn`, `signUp`, `signInWithGoogle`, etc.) to call the initialization service.
3.  **Verification:** Add an integration test that deletes a user's Firestore document, logs them in again, and verifies the document is restored.
4. **Security Rules:** Security Rules must enforce granular access.
    *   **Create:** `allow create: if request.auth.uid == userId && request.resource.data.role == 'user';` (forces the user role).
    *   **Update:** `allow update: if request.auth.uid == userId && request.resource.data.role == resource.data.role;` (prevents role escalation).
    *   **Delete:** Restricted to administrators or a managed account-deletion process.
    *   *See [rules.md](./rules.md) for the complete, production-hardened implementation.*

