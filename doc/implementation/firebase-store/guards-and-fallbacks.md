# Firestore Guards and Fallback Actions

This document defines the standards for implementing "guards" (pre-conditions) and "fallback actions" (error/missing data handling) when interacting with Cloud Firestore in the FoodSavr project.

## 1. Core Philosophy

In a 3-tier architecture, safety is distributed:
*   **Guards** primarily live in the **Service Layer** (logic) and **Security Rules** (server-side).
*   **Fallbacks** are managed in the **Repository Layer** (data defaults) and the **Service Layer** (error recovery).

---

## 2. Guards (Pre-conditions)

### A. Authentication Guard
Never assume a user is logged in at the repository level.
*   **Implementation:** Services must check `IAuthService.currentUser` before calling repository methods that require a `userId`.
*   **Enforcement:** Firestore Security Rules must mirror these checks to prevent unauthorized access.

### B. Existence Guards
Before performing an `update()` or creating a sub-collection document, verify the parent or target exists.
*   **Pattern:** 
    1.  **Read-Before-Write:** In the Service, check if the parent document exists.
    2.  **Transactions:** Use `runTransaction` for operations where existence is a strict requirement for data integrity.

### C. Validation Guards
Use the `Domain Model` to validate data before it reaches the Repository.
*   **Constraint:** Zero business logic in Repositories. If a `Product` requires a `name`, the `Product` model or the `ProductService` must enforce this before `ProductRepository.add()` is called.

---

## 3. Fallback Actions

### A. "Not Found" Fallbacks
When a `get()` operation returns no data:
*   **Repository Level:** Return `null` (standard pattern in `IRepository`).
*   **Service Level:** 
    *   Throw a domain-specific exception (e.g., `ProductNotFoundException`).
    *   Or, return a "Default/Guest" state if appropriate.

### B. "Permission Denied" Fallbacks
Handle cases where Security Rules block an operation.
*   **Action:** Catch `FirebaseException` with code `permission-denied`, log it via `logger.e()`, and notify the UI layer to show an "Access Denied" message or redirect to Login.

### C. Network & Offline Fallbacks
Firestore has built-in persistence, but some actions require "Live" confirmation.
*   **Guarded Writes:** For critical operations (e.g., joining a group), use `await` to ensure the local write is at least queued.
*   **UI Feedback:** Use optimistic UI updates in the View, but provide a "Syncing..." indicator if the network is unavailable.

---

## 4. Environment-Specific Behavior

### Local Emulator (`development`)
*   **Guard Verbosity:** Log every guard failure with full stack traces.
*   **Fallback:** If a required document is missing, the Service may automatically trigger a "Seed Task" to create placeholder data for a smoother developer experience.
*   **Connection:** Guard against a missing emulator connection by checking `FirebaseFirestore.instance.settings.host`.

### Production (`production`)
*   **Guard Verbosity:** Silent failures in the UI; detailed logging in the background (Sentry/Crashlytics).
*   **Fallback:** Never auto-seed data. Show a clear "Data Error" or "Not Found" state to the user.
*   **Security:** Strict Security Rules are the ultimate guard.

---

## 5. Implementation Example

```dart
// lib/services/collection_service.dart

Future<void> addItemToCollection(String collectionId, int productId) async {
  // 1. Guard: Auth
  final user = _authService.currentUser;
  if (user == null) throw UnauthenticatedException();

  // 2. Guard: Existence
  final collection = await _collectionRepo.get(collectionId);
  if (collection == null) {
    // Fallback: Log and throw
    _logger.w('Attempted to add item to non-existent collection: $collectionId');
    throw CollectionNotFoundException();
  }

  try {
    await _collectionRepo.addProduct(collectionId, productId);
  } catch (e) {
    // 3. Fallback: Specific Error Handling
    if (e is FirebaseException && e.code == 'permission-denied') {
      _logger.e('Security Rule Violation for user ${user.uid}');
      // Trigger UI fallback
    }
    rethrow;
  }
}
```
