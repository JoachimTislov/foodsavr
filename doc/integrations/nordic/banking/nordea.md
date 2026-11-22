---
id: nordic-nordea
name: Nordea Open Banking
scope: nordic
category: banking
operator: Nordea Bank Abp
access: [api-partner]
auth: oauth2
data: [purchases]
item_level: false
cost: unknown
user_base: Largest Nordic bank group (DK, FI, NO, SE)
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Nordea Open Banking

PSD2 account information (accounts, balances, transactions) from Nordea. Merchant-level only: shows where and how much was spent, not which items.

## Access

- **api-partner** — Nordea developer portal (`openapi.portal.nordea.com` per Nordea's support page; other sources cite `developer.nordeaopenbanking.com`; current one unconfirmed). Sandbox, then production; production needs regulated TPP status (PSD2 rule, unverified for Nordea specifically). A third-party profile says about four unattended account-information calls per consented account per day (unverified). ([support](https://openapi.portal.nordea.com/support), [Open Banking Tracker](https://openbankingtracker.com/provider/nordea/apis))
- Via the Nordic aggregator [Enable Banking](https://enablebanking.com/accounts-api) (see `nordic/banking/enable-banking.md`).

## Data

Account list, balances, transactions (date, amount, counterparty text). No line items.

## FoodSavr mapping

Grocery-merchant transactions -> "purchase happened" nudges and spend stats; cannot populate inventory.

## Risks and constraints

TPP licence or aggregator contract; PSD2 SCA consent renewal; GDPR financial data.

## Existing work

Official Python examples under the NordeaOB GitHub organisation, per a [Home Assistant thread](https://community.home-assistant.io/t/finance-nordea-bank-documented-and-supported-api-with-python-example-code/137324).

## Sources

- https://openapi.portal.nordea.com/support
- https://openbankingtracker.com/provider/nordea/apis
- https://enablebanking.com/accounts-api
- https://community.home-assistant.io/t/finance-nordea-bank-documented-and-supported-api-with-python-example-code/137324
