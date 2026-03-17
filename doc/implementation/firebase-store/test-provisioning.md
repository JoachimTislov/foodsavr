# Autonomous Test-Data Provisioning

This document outlines the implementation plan for the autonomous creation of missing Firestore documents and schema in test environments (Local Emulator and Remote Test) for the FoodSavr project.

## 1. Objectives

*   **Zero-Manual Setup:** In test environments, all parent documents (e.g., `/users/{uid}`) must be created automatically if a sub-resource action is performed.
*   **Contextual Provisioning:** Auto-provisioning only occurs if the user is authenticated but their document is missing.
*   **Safety:** This behavior is strictly disabled in `production` to prevent data corruption or accidental schema changes.

## 2. Environment Strategy

We use `Config.isDevelopment` and `Config.environment` (from `lib/utils/config.dart`) to gate the auto-provisioning logic.

*   **Local Development:** Uses the Firestore Emulator.
*   **Remote Test:** Uses a dedicated Firebase project/environment.
*   **Production:** Auto-provisioning is completely disabled.

## 3. Core Component: `TestProvisioningService`

A dedicated service handles the "upsert" of parent documents when needed.

*   **Path:** `lib/services/test_provisioning_service.dart`
*   **Responsibilities:**
    *   `ensureUserExists(String userId)`: Checks if `/users/{userId}` exists. If not, creates it with default test data.
    *   `ensureGroupExists(String groupId, String ownerId)`: Checks if `/groups/{groupId}` exists. If not, creates the group and the owner as a `leader`.

## 4. Repository & Service Integration

Instead of modifying repositories, the **Service Layer** utilizes the `TestProvisioningService` when in a test environment.

### Pattern: Guard & Provision

```dart
// lib/services/product_service.dart

Future<void> addProductToInventory(String userId, Product product) async {
  // 1. Environment Check
  if (Config.isDevelopment || Config.environment == 'test') {
    // 2. Autonomous Provisioning
    await _testProvisioningService.ensureUserExists(userId);
  }

  // 3. Standard Repository Call
  await _productRepo.add(product);
}
```

## 5. Testing & Validation

### Integration Tests
1.  **Setup:** Clear the Firestore Emulator state.
2.  **Act:** Authenticate a new test user and attempt to save a sub-resource (e.g., an inventory item).
3.  **Assert:** 
    *   The parent `/users/{userId}` document is created.
    *   The sub-resource (inventory item) is saved successfully.
    *   No manual "seed" script was required.

## 6. Implementation Tasks

1.  **Service Creation:** Implement `TestProvisioningService` with `getIt` registration.
2.  **Environment Setup:** Update `lib/utils/config.dart` to support an explicit `'test'` environment string.
3.  **Service Integration:** Add provisioning calls to `AuthService` (on login) and critical feature services (`ProductService`, `CollectionService`).
4.  **Verification:** Add an integration test case in `integration_test/auth_test.dart` or a new `provisioning_test.dart`.
