---
id: global-taggun
name: Taggun
scope: global
category: receipts
operator: Taggun
access: [api-public]
auth: api-key
data: [line-items, purchases]
item_level: true
cost: freemium
user_base: developer API; user base n/a
tos_risk: low
fit: 4
status: researched
last_verified: 2026-11-21
---

# Taggun

Receipt scanning API focused on merchant, totals and line items.

## Access

- **api-public** — REST API with API key; free tier (limits unverified).

## Data

Returns structured JSON for a receipt image/PDF: merchant, date, totals, tax, and line items (description, quantity, unit price, total). Product codes/EAN are rarely extracted (unverified). Accuracy varies with print quality and language.

## FoodSavr mapping

`purchases` plus `LineItem` from a photo the user takes in-app. Item descriptions are often abbreviated store text and need normalization/matching to products; no expiry.

## Risks and constraints

- Per-scan pricing; line-item accuracy unverified.

## Existing work

- Generic SDKs.

## Sources

- https://www.taggun.io/ — product and docs (verify docs path)
