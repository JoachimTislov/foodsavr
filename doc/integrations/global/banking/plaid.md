---
id: global-plaid
name: Plaid
scope: global
category: banking
operator: Plaid Inc.
access: [api-public]
auth: oauth2
data: [purchases]
item_level: false
cost: freemium
user_base: US, Canada, UK and Europe; very large
tos_risk: low
fit: 2
status: researched
last_verified: 2026-11-21
---

# Plaid

Dominant US aggregator; relevant to FoodSavr mainly for US users. Transactions include merchant name, category and sometimes counterparties; no line items.

## Access

- **api-public** — Link flow, REST API; free Sandbox and limited development tier; production per-item pricing (details unverified).

## Data

Accounts, balances, transactions (booking date, amount, currency, counterparty/merchant name, description, sometimes MCC). Card and bank transactions carry only merchant-level data (merchant name, amount, date, MCC at best): no line items or products.

## FoodSavr mapping

`purchases` at merchant level only: signals that a shop trip happened and its total, useful for matching against receipts or prompting the user to scan one. Cannot populate `LineItem`. Card and bank transactions carry only merchant-level data (merchant name, amount, date, MCC at best): no line items or products.

## Risks and constraints

- Costly per connected account; production approval.

## Existing work

- Official SDKs, Flutter plugin `plaid_flutter` (unverified).

## Sources

- https://plaid.com/docs/ — docs
