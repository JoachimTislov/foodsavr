---
id: se-nordea
name: Nordea Open Banking (Sweden)
scope: se
category: banking
operator: Nordea Bank Abp
access: [api-public]
auth: oauth2
data: [purchases]
item_level: false
cost: free
user_base: Large Nordic bank; Swedish retail customers
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Nordea Open Banking (Sweden)

Nordea launched open banking APIs in Sweden in September 2018 (account information and payment initiation) with a developer portal and sandbox. Nordea is Nordic; a `nordic` entry may overlap.

## Access

- **api-public (regulated)** — portal with Client ID/secret per app (support page on openapi.portal.nordea.com); sandbox supports authorisation flows, account information and payment initiation (per Enable Banking). Live data needs a PSD2 licence. Current portal URL and Swedish AIS endpoint specifics not confirmed.

## Data

Accounts, balances, transactions.

## FoodSavr mapping

Merchant-level purchase signal.

## Risks and constraints

Licence or aggregator required; consent renewal.

## Existing work

None reviewed.

## Sources

- https://www.nordea.com/en/press-and-news/news-and-press-releases/press-releases/2018/09-14-09h00-open-banking-goes-live-in-sweden.html — Sweden launch
- https://enablebanking.com/docs/markets/se/ — Swedish market specifics, Nordea sandbox
- https://openapi.portal.nordea.com/support — portal client credentials
