---
id: se-seb
name: SEB Developer Portal (PSD2)
scope: se
category: banking
operator: Skandinaviska Enskilda Banken AB
access: [api-public]
auth: oauth2
data: [purchases]
item_level: false
cost: free
user_base: One of Sweden's large banks
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# SEB Developer Portal (PSD2)

SEB runs developer.sebgroup.com with account information and payment APIs. Merchant-level transactions only.

## Access

- **api-public (regulated)** — portal opened publicly in 2018 with sandbox data for account information and payments; production data requires a PSD2 licence from a national authority; customer consent through Mobile BankID. Current endpoint details not verified (sources are 2018-2019).
- Aggregator route recommended for an unlicensed app.

## Data

Accounts, balances, transactions (merchant text, amount).

## FoodSavr mapping

Merchant-level purchases; same as `se-swedbank`.

## Risks and constraints

PSD2 licence or aggregator contract; consent renewal.

## Existing work

None reviewed.

## Sources

- https://sebgroup.com/press/news/devportal — portal launch, sandbox, licence and BankID consent
- https://sebgroup.com/press/news/seb-releases-first-live-data-for-psd2-apis — live data release
