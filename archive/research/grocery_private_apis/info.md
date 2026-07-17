# Raw Data from Gist & Search: Helge Sverre Private APIs

## Gist: 80a7f34f874336324184a0c513c2e6a2
The gist contains reverse-engineered API documentation for the three major Norwegian grocery chains: Rema 1000 (Æ), Coop Norway (Coop Medlem), and Trumf (NorgesGruppen).

### 1. Rema 1000 (Æ) API
* Base URL: https://api.rema.no
* Authentication: OAuth 2.0 with PKCE via https://id.rema.no/.
* Key Endpoints:
  * GET /v1/bella/transaction/v2/heads: List all purchase summaries.
  * GET /v1/bella/transaction/v2/rows/{tid}: Get detailed line items (EAN, price, quantity) for a transaction.

### 2. Coop Norway (Coop Medlem) API
* Base URL: https://api.coop.no
* Authentication: OpenID Connect via Auth0 (https://login.coop.no/).
  * GET /user/pay/history/dashboard: Spending overview with monthly breakdowns.
  * GET /user/pay/history/details: Full receipt details including line items and EAN codes.

### 3. Trumf (NorgesGruppen) API
* Base URL: https://platform-rest-prod.ngdata.no/trumf/
* Authentication: Phone number and password exchange for a Bearer token.
  * GET /trumf/husstand/transaksjoner: List recent transactions across Kiwi, Meny, Spar, and Joker.
  * GET /trumf/husstand/transaksjoner/detaljer/{batchid}: Get line item details for a specific purchase.

## Search Results: Helge Sverre
* Helge Sverre decompiled Android apps for Rema 1000 (Æ) and Coop Norway to map their internal APIs.
* He is the creator of Kassal.app, a service for comparing grocery prices and scanning receipts.
* Authentication flows mapped out.
* WhatIBuy acts as a client impersonating the user's mobile app sessions using user credentials.