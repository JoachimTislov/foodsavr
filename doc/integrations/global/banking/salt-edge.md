---
id: global-salt-edge
name: Salt Edge
scope: global
category: banking
operator: Salt Edge Inc.
access: [api-partner]
auth: oauth2
data: [purchases]
item_level: false
cost: paid
user_base: Global, 5,000+ banks (vendor claim, unverified)
tos_risk: low
fit: 2
status: researched
last_verified: 2026-11-21
---

# Salt Edge

Aggregator with Account Information API; Partner/enterprise onboarding.

## Access

- **api-partner** — Salt Edge Account Information API v6 (REST, signed requests); test environment; production by agreement (details unverified).

## Data

Accounts, balances, transactions (booking date, amount, currency, counterparty/merchant name, description, sometimes MCC). Card and bank transactions carry only merchant-level data (merchant name, amount, date, MCC at best): no line items or products.

## FoodSavr mapping

`purchases` at merchant level only: signals that a shop trip happened and its total, useful for matching against receipts or prompting the user to scan one. Cannot populate `LineItem`. Card and bank transactions carry only merchant-level data (merchant name, amount, date, MCC at best): no line items or products.

## Risks and constraints

- Commercial agreement required.

## Existing work

- Official SDKs.

## Sources

- https://docs.saltedge.com/ — docs
