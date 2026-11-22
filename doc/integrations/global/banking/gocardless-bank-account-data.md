---
id: global-gocardless-bank-account-data
name: GoCardless Bank Account Data (ex Nordigen)
scope: global
category: banking
operator: GoCardless
access: [api-public]
auth: oauth2
data: [purchases]
item_level: false
cost: unknown
user_base: Europe, 2,300+ banks (vendor claim, unverified)
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# GoCardless Bank Account Data (ex Nordigen)

Former Nordigen free aggregator. GoCardless' announcement page now points interested parties to sales, which suggests self-serve signup may be closed (unconfirmed).

## Access

- **api-public** — REST API with secret id/key obtaining an access token; requisition flow to bank consent; documented at developer.gocardless.com/bank-account-data. Availability of new signups unverified; check the announcement page.

## Data

Accounts, balances, transactions (booking date, amount, currency, counterparty/merchant name, description, sometimes MCC). Card and bank transactions carry only merchant-level data (merchant name, amount, date, MCC at best): no line items or products.

## FoodSavr mapping

`purchases` at merchant level only: signals that a shop trip happened and its total, useful for matching against receipts or prompting the user to scan one. Cannot populate `LineItem`. Card and bank transactions carry only merchant-level data (merchant name, amount, date, MCC at best): no line items or products.

## Risks and constraints

- New-account availability uncertain.
- 90 days consent and history limits (unverified).

## Existing work

- Used by Firefly III data importer.

## Sources

- https://developer.gocardless.com/bank-account-data/overview — docs
- https://gocardless.com/bank-account-data/announcement — announcement (signup status)
- https://docs.firefly-iii.org/how-to/data-importer/import/gocardless/ — third-party use
