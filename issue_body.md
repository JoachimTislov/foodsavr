### Objective
Refactor the token handling and storage mechanisms within the `OAuthService` to improve robustness, clarity, and efficiency, specifically addressing null case handling and token data storage.

### Important Details / Architecture

1.  **Create/Update `OAuthToken` Model:**
    *   If it doesn't exist, create `lib/models/oauth_token_model.dart`. This model should represent the entire token response, including `accessToken`, `refreshToken`, `accessTokenExpiration`, and potentially `tokenType`, `scope`, etc., as needed.
    *   Ensure the `OAuthToken` model is immutable and supports `json_serializable` for easy serialization to/from JSON. Add `copyWith` for immutability.
    *   If it exists, update `lib/models/oauth_token_model.dart` to include all relevant fields and `json_serializable` setup.

2.  **Refactor `_fetchToken` in `lib/features/third_party_integration/services/oauth_service.dart`:**
    *   **Individual Null Checks:** Modify the `if (accessToken != null && refreshToken != null)` block.
        *   Check `accessToken` and `refreshToken` individually.
        *   If `accessToken` is null, throw an `Exception` with a message like `'Access token is null in OAuth response for provider $provider.'`. Log this error using `_logger.e`.
        *   If `refreshToken` is null, throw an `Exception` with a message like `'Refresh token is null in OAuth response for provider $provider.'`. Log this error using `_logger.e`.
    *   **Construct `OAuthToken`:** After successfully parsing `accessToken`, `refreshToken`, and `accessTokenExpiration`, construct an `OAuthToken` instance from the `data` map.

3.  **Update Token Storage in `OAuthService`:**
    *   **`save` Method:**
        *   Change the signature of `save` to accept an `OAuthToken` object directly, or at least a `Map<String, dynamic>` that can be used to construct an `OAuthToken`.
        *   Serialize the `OAuthToken` object (or the map representing it) into a JSON string using `jsonEncode`.
        *   Store this single JSON string in `SecureStorageService` under a key like `_generateKey(provider)`. This consolidates token data storage.
    *   **`readOAuthToken` Method:**
        *   Retrieve the single JSON string from `SecureStorageService` using the `provider`-derived key.
        *   If the string is not null, deserialize it into an `OAuthToken` object using `OAuthToken.fromJson` (or equivalent).
        *   Handle cases where the retrieved string is null or cannot be deserialized, returning `null` or throwing a specific error as appropriate.
        *   The return type of `readOAuthToken` should be `Future<OAuthToken?>`.

4.  **Update `_generateKey`:**
    *   Ensure `_generateKey` is used consistently for both saving and reading the consolidated token data.

### Verification

1.  **Unit Tests for `OAuthService`:**
    *   **Null Handling:**
        *   Add/modify tests for `_fetchToken` to verify that `Exception`s are thrown with specific messages when `access_token` or `refresh_token` are missing from the `response.body`.
    *   **Token Serialization/Deserialization:**
        *   Add/modify tests for `save` to ensure `OAuthToken` objects are correctly serialized to JSON and stored.
        *   Add/modify tests for `readOAuthToken` to ensure JSON strings are correctly retrieved and deserialized back into `OAuthToken` objects.
        *   Test `readOAuthToken` returns `null` when no token is stored.
        *   Test `readOAuthToken` gracefully handles malformed JSON in storage (e.g., returns `null` or throws a custom error).
    *   **`OAuthToken` Model:**
        *   Add unit tests for the `OAuthToken` model's `fromJson` and `toJson` methods to ensure correct serialization and deserialization.
2.  **Integration Tests:**
    *   Run existing integration tests that involve OAuth flows to ensure no regressions.
    *   Consider adding a dedicated integration test that performs a full OAuth login, verifies token storage and retrieval, and then logs out, ensuring the lifecycle works as expected with the new storage mechanism.
