---
id: global-tink
name: Tink
scope: global
category: banking
operator: Tink AB (Visa)
access: [api-partner]
auth: oauth2
data: [purchases]
item_level: false
cost: paid
user_base: Europe-wide, 3,400+ banks (vendor claim, unverified)
tos_risk: low
fit: 2
status: researched
last_verified: 2026-11-21
---

# Tink

Open-banking aggregator (PSD2) with strong Nordic coverage. Commercial agreement and a licensed or sponsored setup needed.

## Access

- **api-partner** — Tink Link + Data APIs; OAuth2; pricing is quote-based per Tink's pricing page; no free production tier found.

## Data

Accounts, balances, transactions (booking date, amount, currency, counterparty/merchant name, description, sometimes MCC). Card and bank transactions carry only merchant-level data (merchant name, amount, date, MCC at best): no line items or products.

## FoodSavr mapping

`purchases` at merchant level only: signals that a shop trip happened and its total, useful for matching against receipts or prompting the user to scan one. Cannot populate `LineItem`. Card and bank transactions carry only merchant-level data (merchant name, amount, date, MCC at best): no line items or products.

## Risks and constraints

- Production requires sales contact; consent renewal every 180 days (PSD2, unverified).

## Existing work

- Official SDKs (unverified).

## Sources

- https://tink.com/pricing — pricing tiers
- https://tink.com/faq/ — FAQ
