# Rema 1000 Æ API Integration

## Background
The Rema 1000 "Æ" app uses an internal backend API. This API is not officially public, but has been extensively reverse-engineered by the community, notably by Helge Sverre and Starefossen. 

The official developer portal (developer.rema.no) strictly forbids scraping and competitor usage, so utilizing this reverse-engineered API is the primary method for personal receipt aggregation or similar private tools.

## Authentication
Rema 1000 uses OAuth 2.0 with PKCE (Proof Key for Code Exchange) for authentication.

- **Identity Provider:** `id.rema.no`
- **Authorization Endpoint:** `https://id.rema.no/authorization`
- **Token Endpoint:** `https://id.rema.no/token`
- **Client ID:** `android-251010`
- **Scope:** `all`

## API Usage
All requests to the backend (`api.rema.no` or `esb-production-apim.azure-api.net`) require two headers:
1. `Authorization: Bearer <access_token>` (obtained via the OAuth flow)
2. `Ocp-Apim-Subscription-Key: fb5e24884b504d0bad761098f77e6605` (A hardcoded Azure API Management key from the Android APK).

## Endpoints
### Newer API (`no.rema.bella` package based):
- **Base URL:** `https://api.rema.no` (or `https://esb-production-apim.azure-api.net`)
- **List Purchases (Headers):** `GET /v1/bella/transaction/v2/heads`
- **Receipt Details (Rows):** `GET /v1/bella/transaction/v2/rows/{transactionId}`
- **Coupons:** `/coupon/all`, `/coupon/activate`, `/coupon/swap`
- **GDPR Data Access:** `/v1/sardar/DataAccessRequest`

### Older/Alternative API (`node-rema-ae-api` wrapper):
- **Base URL:** `https://api.rema.no`
- **Top Products:** `GET /gordo/topList/{userid}`
- **Product Offers:** `GET /gordo/offers/{userid}`
- **Saving Overview:** `GET /gordo/heads/{userid}`

## Existing Community Tools
- `Starefossen/node-rema-ae-api` (Node.js wrapper)
- `wulffern/remaquery` (Python script)
- Helge Sverre's API dumps (`coop-norway-api.openapi.json` Gist which includes Rema 1000 mappings)
- Kassal.app (Commercial/hobbyist aggregator built using these methods)

## Safety & Legal
Since there is no open public API for general usage, this relies on pretending to be the Æ mobile app.

### Commercial Usage & Enforcement
Rema 1000 strictly prohibits the use of their digital services, including the reverse-engineered Æ app API, for commercial purposes without an explicit partnership agreement. 
- **Terms of Service (ToS) Violations:** The terms of use for the Æ app forbid reverse engineering, scraping, and using the data for commercial gain. A user is only granted a license for personal, non-commercial use.
- **Aggregators and Competitors:** Rema 1000 actively blocks third-party services that attempt to use their APIs for price comparison, commercial budgeting, or competitor analysis. Building public tools or commercial SaaS using these endpoints often results in Cease & Desist (C&D) letters or ToS violation notices from their legal team (as noted by developers in the Norwegian tech community like Helge Sverre).
- **Active Enforcement:** If a commercial service impersonates the Æ app to fetch data on behalf of users, Rema 1000 monitors and mitigates this by flagging traffic anomalies (e.g., high request volumes from cloud IP blocks like AWS or Google Cloud, unusual simultaneous logins, and misuse of the hardcoded `Ocp-Apim-Subscription-Key`).
- **The Official Route:** Companies wishing to integrate commercially must go through the official Rema 1000 Developer Portal (developer.rema.no) and sign a B2B agreement. However, these APIs are highly restrictive and are primarily intended for official suppliers and internal systems, not third-party consumer aggregators.

### Personal Use
Using the `id.rema.no` PKCE flow and `api.rema.no` endpoints is generally only feasible if it is for **strictly personal, private use** (e.g., a developer pulling their own receipts into a personal dashboard).

### The "No-Code" Supported Alternative
A GDPR export from the Æ app (Profile -> Terms & Privacy -> View my data -> Send in machine-readable format) is an officially supported, manual way to get your personal data as a JSON file, which can then be imported into third-party tools without violating API terms.