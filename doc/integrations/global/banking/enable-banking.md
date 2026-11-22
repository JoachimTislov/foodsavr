---
id: global-enable-banking
name: Enable Banking
scope: global
category: banking
operator: Enable Software Oy (Finland)
access: [api-public]
auth: oauth2
data: [purchases]
item_level: false
cost: unknown
user_base: Europe, 2,500+ banks (unverified)
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Enable Banking

Finnish PSD2 aggregator with sandbox on signup; a 2026 comparison blog reports production access is quote-based (secondary source). Restricted production for personal use may exist (unverified).

## Access

- **api-public** — REST API with JWT-signed requests; sandbox free; production via sales form (per third-party blog).

## Data

Accounts, balances, transactions (booking date, amount, currency, counterparty/merchant name, description, sometimes MCC). Card and bank transactions carry only merchant-level data (merchant name, amount, date, MCC at best): no line items or products.

## FoodSavr mapping

`purchases` at merchant level only: signals that a shop trip happened and its total, useful for matching against receipts or prompting the user to scan one. Cannot populate `LineItem`. Card and bank transactions carry only merchant-level data (merchant name, amount, date, MCC at best): no line items or products.

## Risks and constraints

- Production pricing and personal-use terms unverified.

## Existing work

- Open-source clients exist (unverified).

## Sources

- https://enablebanking.com/docs/ — docs (verify path)
- https://dev.to/johnfrandsen/the-cheapest-open-banking-apis-for-small-businesses-and-indie-builders-in-2026-5cab — third-party pricing comparison
