---
id: global-yapily
name: Yapily
scope: global
category: banking
operator: Yapily Ltd
access: [api-partner]
auth: oauth2
data: [purchases]
item_level: false
cost: paid
user_base: UK and Europe, 2,000+ banks (vendor claim, unverified)
tos_risk: low
fit: 2
status: researched
last_verified: 2026-11-21
---

# Yapily

Open banking API platform; sandbox with signup, production through commercial plan.

## Access

- **api-partner** — REST API with application id/secret; consent flow; pricing quote-based (unverified).

## Data

Accounts, balances, transactions (booking date, amount, currency, counterparty/merchant name, description, sometimes MCC). Card and bank transactions carry only merchant-level data (merchant name, amount, date, MCC at best): no line items or products.

## FoodSavr mapping

`purchases` at merchant level only: signals that a shop trip happened and its total, useful for matching against receipts or prompting the user to scan one. Cannot populate `LineItem`. Card and bank transactions carry only merchant-level data (merchant name, amount, date, MCC at best): no line items or products.

## Risks and constraints

- Commercial agreement; AIS licence or sponsorship needed.

## Existing work

- Official SDKs.

## Sources

- https://docs.yapily.com/ — docs
