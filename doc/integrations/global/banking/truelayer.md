---
id: global-truelayer
name: TrueLayer
scope: global
category: banking
operator: TrueLayer Ltd
access: [api-public]
auth: oauth2
data: [purchases]
item_level: false
cost: freemium
user_base: UK and Europe
tos_risk: low
fit: 2
status: researched
last_verified: 2026-11-21
---

# TrueLayer

UK/EU open banking provider offering Data API for accounts and transactions.

## Access

- **api-public** — OAuth2 Data API; sandbox free; production by agreement (details unverified).

## Data

Accounts, balances, transactions (booking date, amount, currency, counterparty/merchant name, description, sometimes MCC). Card and bank transactions carry only merchant-level data (merchant name, amount, date, MCC at best): no line items or products.

## FoodSavr mapping

`purchases` at merchant level only: signals that a shop trip happened and its total, useful for matching against receipts or prompting the user to scan one. Cannot populate `LineItem`. Card and bank transactions carry only merchant-level data (merchant name, amount, date, MCC at best): no line items or products.

## Risks and constraints

- Production approval and cost unverified.

## Existing work

- Official SDKs.

## Sources

- https://docs.truelayer.com/ — docs
