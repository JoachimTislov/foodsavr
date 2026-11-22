---
id: no-nordea
name: Nordea Norway (open banking)
scope: no
category: banking
operator: Nordea Bank Abp, filial i Norge
access: [api-public]
auth: oauth2
data: [purchases]
item_level: false
cost: unknown
user_base: unknown
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Nordea Norway

Nordea offers PSD2 Account Information and Payment Initiation through its developer portal; Norway coverage details are not confirmed.

## Access

- **api-public** (regulated) — Bits lists `https://developer.nordeaopenbanking.com/` for Nordea; Nordea support pages point to `openapi.portal.nordea.com` and a rebrand to "Nordea API Market" (current address unconfirmed). Live access uses client credentials plus an administrator approving in the Nordea Codes app; corporate APIs need a sales agreement. TPP status required for PSD2 AIS.
- Yapily's docs list Nordea Account Information and Payment Initiation scopes (aggregator route).

## Data

Accounts, balances, transactions (merchant-level). No line items.

## FoodSavr mapping

Merchant-level grocery spend hints only.

## Risks and constraints

Portal in transition; AISP status or aggregator needed.

## Existing work

None specific to FoodSavr.

## Sources

- https://www.bits.no/?p=2161 — Nordea portal URL
- https://openapi.portal.nordea.com/support — support page
- https://docs.yapily.com/institution-configurations/nordics/Nordea.md — aggregator scopes
