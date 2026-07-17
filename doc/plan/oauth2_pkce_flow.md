# Development Plan: Robust OAuth 2.0 PKCE Flow for User Data Retrieval

**Date:** 2026-05-03
**Status:** Planned
**Objective:** Securely authorize a public mobile client (FoodSavr) to access a third-party resource server (e.g., Storebox, Rema, Trumf, or Coop) on behalf of the user, using the OAuth 2.0 Authorization Code Flow with PKCE (Proof Key for Code Exchange).

---

## 1. Architectural Overview

PKCE prevents authorization code interception attacks on public clients (mobile apps). The flow operates as follows:
1. **Client (Flutter)** generates a random `code_verifier` and a hashed `code_challenge`.
2. **Client** opens a secure browser tab (Custom Tabs/ASWebAuthenticationSession) requesting an authorization `code`, sending the `code_challenge`.
3. **User** logs in and grants consent on the Provider's web page.
4. **Provider** redirects back to the Client app via Deep Link with the authorization `code`.
4.1 **Client** must verify returned `state` exactly matches the locally stored `state` before exchanging the `code`.
4.2 If OIDC scopes are used (`openid`), include a `nonce` in auth request and validate it from the ID token.
5. **Client** POSTs the `code` and the original unhashed `code_verifier` to the Provider's Token Endpoint.
6. **Provider** verifies the `code_verifier` matches the previous `code_challenge` and issues an **Access Token** (and Refresh Token).
7. **Client** uses the Access Token to securely retrieve User Data from the Provider's API.

---

## 2. Phase 1: Environment & Setup

### 2.1. Provider Registration
- **Requirements:**
  - Set the `redirect_uri` to a custom app scheme (e.g., `foodsavr://oauth2redirect` or an App Link like `https://foodsavr.app/auth`).
  - Retrieve the `client_id` and discovery document URL (or explicit Auth/Token endpoints).

### 2.2. Dependencies
- **Task:** Add required packages to `pubspec.yaml`.
- **Packages:**
  - `flutter_appauth`: Industry standard wrapper around native AppAuth libraries (handles PKCE generation and secure browser tabs automatically).
  - `flutter_secure_storage`: For securely storing Access and Refresh Tokens natively (Keychain/Keystore).
  - `dio` or `http`: For making authenticated API requests.
  - `uni_links` or `app_links` (optional, if `flutter_appauth` needs external deep-link handling, though it usually handles its own redirects natively).

### 2.3. Deep Linking Configuration
- **Android (`android/app/build.gradle` & `AndroidManifest.xml`):**
  - Add manifest placeholders for `appAuthRedirectScheme`.
- **iOS (`ios/Runner/Info.plist`):**
  - Add the `CFBundleURLTypes` for the registered custom scheme.

---

## 3. Phase 2: Core Authentication Logic (Services & DI)

*Per project guidelines, all business logic and external API calls must reside in Services, registered via GetIt.*

### 3.1. `OAuthService` Interface
- Define an abstract interface in `lib/interfaces/oauth_service.dart`.
  ```dart
  abstract class OAuthService {
    Future<void> authorize();
    Future<String?> getValidAccessToken();
    Future<void> logout();
  }
  ```

### 3.2. `AppAuthOAuthService` Implementation
- Implement the logic using `flutter_appauth` in `lib/services/app_auth_oauth_service.dart`.
  - **Authorize:** Use `FlutterAppAuth.authorizeAndExchangeCode()` which automatically:
    - Generates the PKCE verifier/challenge.
    - Opens the secure web view.
    - Intercepts the redirect URL.
    - Exchanges the code for the token.
  - **Token Storage:** Pass the resulting tokens (Access, Refresh, ID Token) to a `SecureStorageService`.
  - **Refresh Logic:** In `getValidAccessToken()`, check token expiration. If expired, call `FlutterAppAuth.token()` with `GrantType.refreshToken` before returning the new access token.

### 3.3. Dependency Injection
- Register `OAuthService` and `SecureStorageService` as singletons/lazy singletons in `lib/injection.dart`.

---

## 4. Phase 3: Retrieving User Data

### 4.1. The Data Provider Service (e.g., `ThirdPartyUserService`)
- Create a dedicated service to fetch user profile data (e.g., `lib/services/storebox_service.dart`).
- Inject the `OAuthService`.
- **Logic:**
  1. Call `await oauthService.getValidAccessToken()`.
  2. If null, throw an `UnauthorizedException` (which the UI will catch to prompt a login).
  3. Create an HTTP GET request to the Provider's `/userinfo` or `/profile` endpoint.
  4. Attach the header: `Authorization: Bearer $accessToken`.
  5. Parse the JSON response into a Dart model (e.g., `ThirdPartyProfileModel`).

---

## 5. Phase 4: UI Integration (View Layer)

*Views should remain dumb and only react to State.*

### 5.1. Connection View (`lib/views/integration_settings_view.dart`)
- **State:** `disconnected`, `authorizing`, `connected`, `error`.
- **Action:** A button "Connect to [Provider]" that calls a method on the View's Controller/ViewModel.
- **Controller Logic:**
  - Call `await getIt<OAuthService>().authorize()`.
  - Call `await getIt<ThirdPartyUserService>().fetchUserProfile()`.
  - Update the UI state with the fetched user data.

---

## 6. Phase 5: Security & Edge Cases
- Ensure all sensitive data (tokens) are stored securely and never logged.
- Only prompt the user to re-authenticate when necessary (e.g., token expiration or revocation).

### 6.1. Token Revocation & Expiration
- Ensure that if a Refresh Token fails (e.g., the user revoked access from the provider's website), the local secure storage is cleared, and the user is gracefully redirected back to the unauthenticated state.

### 6.2. Network & Timeout Handling
- Implement retry mechanisms or proper timeout exceptions for the token exchange and data retrieval phases, surfacing human-readable errors via `easy_localization`.

### 6.3. Testing Strategy
- **Unit Tests:** Mock the `OAuthService` to test that `ThirdPartyUserService` correctly attaches the Bearer token and parses the JSON response.
- **Integration Tests:** Use mock local storage and a fake token endpoint to verify the refresh logic flow.
