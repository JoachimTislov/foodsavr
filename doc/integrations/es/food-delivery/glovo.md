---
id: es-glovo
name: Glovo
scope: es
category: food-delivery
operator: Delivery Hero (Glovo)
access: [api-partner, export, bot]
auth: oauth2
data: [orders]
item_level: true
cost: partner
user_base: Spain, Italy, Portugal, Poland, others
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Glovo

Delivery platform for restaurants and groceries (Glovo Express/Supermarkets). Partner integration APIs are for stores; consumers have no API.

## Access

- **api-partner** — Glovo partner/integration API for stores (docs gated, unverified).
- **export** — GDPR request.
- **bot** — account scraping.

## Data

Merchant-side orders; consumer export unknown.

## FoodSavr mapping

Meal logging; grocery orders give line items.

## Risks and constraints

Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR.

## Existing work

None found in the search.

## Sources

- https://glovoapp.com — operator site
