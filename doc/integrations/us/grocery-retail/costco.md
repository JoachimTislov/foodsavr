---
id: us-costco
name: Costco
scope: us
category: grocery-retail
operator: Costco Wholesale Corporation
access: [bot, api-private]
auth: username-password
data: [purchases, line-items]
item_level: true
cost: free
user_base: Tens of millions of US members (unverified)
tos_risk: high
fit: 3
status: researched
last_verified: 2026-11-21
---

# Costco

No public API. Members' in-warehouse and online receipts are reachable through Costco's web GraphQL backend, used by community receipt downloaders.

## Access

- **api-private** — Costco.com GraphQL receipt query used by browser extension harrykhh/Costco-Receipt-Downloader; requires login.
- **bot** — TechStud Costco Receipt Downloader (script, personal archiving).

## Data

Warehouse receipts with itemised lines (item number, description, price), tax, warehouse. No EAN observed (unverified).

## FoodSavr mapping

Receipts to `LineItem` through user-triggered extension or manual file; bulk packs and abbreviated descriptions need normalisation.

## Risks and constraints

Private API/ToS risk; not endorsed by Costco.

## Existing work

- https://github.com/harrykhh/Costco-Receipt-Downloader
- https://techstud.github.io/TCRDD/Downloader

## Sources

- https://github.com/harrykhh/Costco-Receipt-Downloader — extension
- https://techstud.github.io/TCRDD/Downloader — downloader
- https://gist.github.com/dlh3/7e18fec42cc7c43d51e93a6d2bcac6fb — receipts extractor gist
