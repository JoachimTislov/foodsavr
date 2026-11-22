---
id: global-klippa
name: Klippa
scope: global
category: receipts
operator: Klippa App B.V. (NL)
access: [api-public]
auth: api-key
data: [line-items, purchases]
item_level: true
cost: paid
user_base: developer API; user base n/a
tos_risk: low
fit: 4
status: researched
last_verified: 2026-11-21
---

# Klippa

Dutch document OCR/parsing API with receipt model and EU data residency.

## Access

- **api-public** — REST API with API key; paid plans, trial available (unverified).

## Data

Returns structured JSON for a receipt image/PDF: merchant, date, totals, tax, and line items (description, quantity, unit price, total). Product codes/EAN are rarely extracted (unverified). Accuracy varies with print quality and language.

## FoodSavr mapping

`purchases` plus `LineItem` from a photo the user takes in-app. Item descriptions are often abbreviated store text and need normalization/matching to products; no expiry.

## Risks and constraints

- Commercial plan; EU hosting is an advantage for GDPR.

## Existing work

- Generic SDKs.

## Sources

- https://www.klippa.com/en/ocr/ — product
