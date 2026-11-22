---
id: no-coop-norge
name: Coop Norge (Coop medlem; Extra, Obs, Prix, Mega)
scope: no
category: grocery-retail
operator: Coop Norge SA
access: [api-private]
auth: oidc
data: [purchases, line-items, offers, lists, products]
item_level: true
cost: free
user_base: Coop says the member app has about 1 million weekly users
tos_risk: high
fit: 5
status: researched
last_verified: 2026-11-21
---

# Coop Norge (Coop medlem)

One member app (Coop medlem) covers Obs, Extra, Coop Prix, Coop Mega, Coop Marked, Matkroken, Obs Bygg and Byggmix. It offers membership card, Coopay, shopping list, personal coupons and digital receipts. FoodSavr has only a stub client (`coop_client.dart`, tracked in #194). Sub-brands share one login, so one entry covers all.

## Access

- **api-private** — reverse-engineered REST at `api.coop.no` (a staging host is mentioned in the gist). Login: OpenID Connect via Auth0 at `login.coop.no`, Authorization Code + PKCE (S256). Payment step-up uses the Aera SDK (Coopay); not needed for read-only history.
- No official developer API or partner programme found.

## Data

- Purchase history: dashboard, list, monthly breakdown, details (line items), search with pagination, receipt PDF.
- Line items include EAN (field `prodtxt3` per the project plan), name, price, quantity.
- Personal offers/coupons (list, activate, swap), family management, store list; shopping lists via gRPC. Many endpoints have no known response schema.

## FoodSavr mapping

Purchases to `LineItem` with EAN; offers to offer data. Quantity/weight semantics and expiry unverified.

## Risks and constraints

- Private API, can change without notice; ToS probably forbids it. Consent-based (GDPR access right).
- Auth0 flow needs WebView/PKCE handling; app-store reviews report login problems in the official app (impact on API unverified).
- Do not record client ids or keys in docs.

## Existing work

- Helge Sverre gist (spec derived from the Flutter app).
- No open-source client or MCP server found.

## Sources

- https://gist.github.com/HelgeSverre/80a7f34f874336324184a0c513c2e6a2 — endpoints, auth
- https://apps.apple.com/no/app/id992134528 — app listing: digital receipts, chains covered
- doc/plan/grocery-private-api-integration.md
