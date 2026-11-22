---
id: pl-biedronka
name: Biedronka
scope: pl
category: grocery-retail
operator: Jerónimo Martins (Biedronka)
access: [api-private]
auth: username-password
data: [purchases, offers]
item_level: true
cost: free
user_base: Poland #1 grocer; Moja Biedronka app
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# Biedronka

Largest Polish retailer. An unofficial client for the mobile app (`rei-x/biedronka-client`) exists; login needs a Polish phone number via Playwright.

## Access

- **api-private** — mobile API via `biedronka-client` (npm, MIT, Playwright login).

## Data

Receipts/offers per client README (verify).

## FoodSavr mapping

Receipts to purchases/`LineItem` if exposed.

## Risks and constraints

Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR.

## Existing work

`rei-x/biedronka-client`.

## Sources

- https://awesome.ecosyste.ms/projects/github.com%2Frei-x%2Fbiedronka-client — client listing
