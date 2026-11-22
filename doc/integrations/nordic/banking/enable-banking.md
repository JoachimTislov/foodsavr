---
id: nordic-enable-banking
name: Enable Banking
scope: nordic
category: banking
operator: Enable Banking Oy (Finland)
access: [api-public]
auth: oauth2
data: [purchases]
item_level: false
cost: unknown
user_base: Open-banking aggregator with Nordic bank coverage; also other EU markets (unverified list)
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Enable Banking

Finnish PSD2 aggregator that fronts many banks behind one Accounts API. Included because it is Nordic-centred (Tink and GoCardless are global and skipped). Merchant-level data only.

## Access

- **api-public** — Accounts API at `api.enablebanking.com`, docs on [enablebanking.com](https://enablebanking.com/accounts-api). Pricing, free tier, and whether a restricted production mode exists for unlicensed apps were not verified (unverified).

## Data

Accounts, balances, transactions with counterparty text. No item data.

## FoodSavr mapping

As `nordic-nordea`: spend and merchant signals only.

## Risks and constraints

Third-party processing of financial data; recurring re-consent; regulator status of FoodSavr vs the aggregator needs legal review.

## Existing work

Not researched.

## Sources

- https://enablebanking.com/accounts-api
- https://api.enablebanking.com/
