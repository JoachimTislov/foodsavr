# Coop Norway (Coop Mega) App API Integration

## Background
Coop Norge (which includes Coop Mega, Obs, Extra, etc.) does not provide a public "Membership" or "Grocery Receipt" API for external developers or consumers. The official developer portals (e.g., PSD2 API at `psd2.kreditt.coop.no`) are strictly for banking/payment services (Open Banking) and do not provide itemized grocery receipts.

To retrieve grocery data programmatically on behalf of a person, developers have reverse-engineered the internal APIs used by the official **Coop Medlem** Android/iOS app (`no.coop.members`).

## Authentication
The Coop app relies on OpenID Connect (OIDC) through an Auth0-based identity provider.
- **Base URL:** `https://api.coop.no`
- **Identity Provider (Issuer):** `https://login.coop.no/.well-known/openid-configuration`
- **Flow:** It uses an OAuth 2.0 flow (likely Authorization Code with PKCE, similar to Rema) to obtain a Bearer token.

## Reverse-Engineered Endpoints
Research (notably by Helge Sverre in February 2026) has mapped out over 50 internal endpoints used by the Flutter-based mobile app. 

### Purchase History & Receipts
- **List Purchases (Headers):** `GET /user/pay/history/list` 
  - Returns a list of transaction stubs with basic metadata.
- **Receipt Details (Line Items):** `GET /user/pay/history/details`
  - Returns structured JSON including product names, EAN codes (`prodtxt3`), prices, applied discounts, and timestamps.
- **PDF Receipts:** `GET /user/pay/history/receipt.pdf?receiptid={id}`
  - Allows downloading the physical receipt rendering.

### Additional Member Features
- **Coupons & Offers:** APIs for viewing and activating personalized coupons.
- **Shopping Lists:** Synchronization of lists via WebSockets.
- **GDPR Export:** Like Rema, Coop must comply with GDPR. There are endpoints (or in-app buttons) for "Data Access Requests" to export purchase history directly.

## Technical Considerations & Scraping
1. **Reverse Engineering Difficulty:** The Coop APK often uses 32-bit native libraries and is built with Flutter. Intercepting the traffic usually requires SSL unpinning on a physical Android device using tools like Frida or mitmproxy.
2. **Official GitHub (`coopnorge`):** Coop Norge has a GitHub organization. While they don't publish the REST API, they do have a repository `coopnorge/demos` that explicitly includes a Python Selenium webscraper. This indicates that even internally, web scraping of `coop.no` might be considered a viable fallback when direct APIs are unavailable.
3. **Data Identifiers:** Products in the Coop system are typically identified by their EAN/GTIN barcodes.

## Safety & Legal (Commercial Use)
Similar to Rema 1000:
- **Terms of Service:** Using internal APIs for automated scraping or building commercial third-party aggregators is against the Terms of Service.
- **Enforcement:** Coop Norge actively protects its pricing and consumer data. Commercial apps attempting to aggregate this data (like the exposed "Spenderlog" app) have faced legal and technical countermeasures.
- **Personal Use:** Using these endpoints for a personal, private dashboard (e.g., using a tool like Kassal.app or a custom script) is technically feasible but remains an unsupported workaround.
- **Supported Export:** The most compliant way to get historical data is to use the app's GDPR "Export My Data" feature to receive a machine-readable format.