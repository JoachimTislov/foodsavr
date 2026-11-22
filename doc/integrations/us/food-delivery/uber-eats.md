---
id: us-uber-eats
name: Uber Eats
scope: us
category: food-delivery
operator: Uber Technologies
access: [api-partner, export]
auth: oauth2
data: [orders]
item_level: false
cost: partner
user_base: Global; large US base
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Uber Eats

Uber Eats Marketplace APIs serve restaurants and POS vendors (menus, orders, stores). No consumer order API.

## Access

- **api-partner** — developer.uber.com/docs/eats; NDA and API licence required, whitelisting, sandbox available.
- **export** — Uber privacy 'download your data' (unverified).

## Data

Merchant-side orders via webhooks.

## FoodSavr mapping

Not usable for diner history; email receipts or data export only.

## Risks and constraints

Partner-gated; strict quality requirements.

## Existing work

- None relevant.

## Sources

- https://developer.uber.com/docs/eats/introduction — Marketplace APIs
- https://developer.uber.com/docs/eats/guides/getting-started — NDA/approval
