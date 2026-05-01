# Manual Integration Plan: Norwegian Grocery Private APIs

This plan outlines the approach to explicitly act on a user's behalf—with their consent—to retrieve receipt and grocery data from Rema 1000 (Æ), Coop (Medlem), and Trumf (NorgesGruppen). It is based on the reverse-engineered APIs documented by Helge Sverre and the integration strategies used by apps like WhatIBuy.

## 1. Overview & Strategy

Since no official B2B APIs exist for these grocery chains, the integration relies on **"Bring Your Own Credentials" (BYOC) / Client Impersonation**. 
1. The user provides explicit consent and their login credentials for each respective app.
2. Our backend acts as a mobile app client, authenticating directly against the grocery chains' identity providers (IdP).
3. We retrieve OAuth/Bearer tokens and periodically poll the internal APIs for new digital receipts and transaction rows.
4. The retrieved data is normalized into a unified receipt format (EAN, Name, Price, Quantity).

*Note: This operates in a gray area regarding the grocery chains' Terms of Service (ToS), which typically forbid commercial scraping. Explicit GDPR-compliant user consent is the primary legal defense for retrieving personal data on their behalf.*

---

## 2. Step-by-Step Implementation Guide

### Step 1: User Consent & Credential Management
*   **UI/UX:** Present a clear onboarding flow explaining *why* we need access and *what* data we will pull. Request explicit GDPR consent (Article 15: Right of access).
*   **Security:** If storing passwords (e.g., Trumf), they must be heavily encrypted at rest. For OIDC/OAuth chains (Rema, Coop), store the **Refresh Tokens** securely (e.g., using a KMS) so the user doesn't have to repeatedly log in.

### Step 2: Implement Authentication Flows
Each chain uses a distinct authentication mechanism that must be mimicked in the backend.

#### A. Rema 1000 (Æ)
*   **IdP:** `https://id.rema.no/` (OAuth 2.0 with PKCE).
*   **Client ID:** `android-251010` (as extracted from the APK).
*   **Flow:** Implement a standard PKCE flow. You will likely need to render the login page in a hidden WebView or intercept the callback to exchange the authorization code for an Access Token.
*   **Required Header:** All API calls require `Ocp-Apim-Subscription-Key: fb5e24884b504d0bad761098f77e6605`.

#### B. Coop (Coop Medlem)
*   **IdP:** `https://login.coop.no/` (Auth0 OpenID Connect).
*   **Flow:** Similar to Rema, this requires navigating an Auth0 login flow to obtain an Access Token/Bearer token.

#### C. Trumf (NorgesGruppen - Kiwi, Meny, Spar, Joker)
*   **IdP / Base:** `https://platform-rest-prod.ngdata.no/trumf/`
*   **Flow:** A direct exchange of the user's phone number and password for a Bearer token.

### Step 3: Implement Data Polling (The APIs)
Once authenticated, use the Bearer tokens to poll for transaction history. To avoid triggering rate limits or anti-bot measures, poll infrequently (e.g., once a day or on manual refresh).

#### Rema 1000 (Æ)
1.  **Get Transactions:** `GET https://api.rema.no/v1/bella/transaction/v2/heads`
2.  **Get Line Items:** `GET https://api.rema.no/v1/bella/transaction/v2/rows/{transactionId}`
    *   *Extract `ean`, `name`, `amount`, and `price`.*

#### Coop
1.  **Get Transactions:** `GET https://api.coop.no/user/pay/history/dashboard` or `/list`
2.  **Get Line Items:** `GET https://api.coop.no/user/pay/history/details`
    *   *This endpoint returns full receipt details including `prodtxt3` (EAN) and price.*

#### Trumf
1.  **Get Transactions:** `GET https://platform-rest-prod.ngdata.no/trumf/husstand/transaksjoner`
2.  **Get Line Items:** `GET https://platform-rest-prod.ngdata.no/trumf/husstand/transaksjoner/detaljer/{batchid}`

### Step 4: Normalization & Storage
*   **Mapping:** Each API returns JSON with different keys. Create a unified `Receipt` and `LineItem` interface in your backend.
    *   Map Rema's `amount` / Coop's `price` to a standard currency format.
    *   Normalize EAN/GTIN codes (padding to 13/14 digits if necessary).
*   **Sync Logic:** Keep track of the `last_sync_timestamp` or `last_transaction_id` per user to only fetch *new* receipts.

### Step 5: Handling Instability (The "WhatIBuy" Problem)
Because these are private, undocumented APIs, they **will** break without warning when the grocery chains update their apps.
*   **Monitoring:** Implement robust error monitoring (e.g., Sentry) specifically for 401/403 (Authentication failed) and 404/400 (Endpoint changed) errors on these sync tasks.
*   **User Alerts:** When a sync fails repeatedly due to an expired token or changed login flow, prompt the user in-app to "Reconnect [Store Name]".
