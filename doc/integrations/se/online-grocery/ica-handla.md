---
id: se-ica-handla
name: ICA Handla (online grocery)
scope: se
category: online-grocery
operator: ICA Gruppen AB (individual ICA stores)
access: [api-private, mcp, bot]
auth: bankid
data: [orders, products, prices]
item_level: true
cost: free
user_base: ICA stores offering home delivery or pickup in Sweden (count unverified)
tos_risk: high
fit: 3
status: researched
last_verified: 2026-11-21
---

# ICA Handla (online grocery)

ICA's e-commerce for delivery and pickup, run per ICA store. Orders hold item-level data in the account, but no documented way to read order history was found.

## Access

- **api-private** — ica-hub (community MCP) exposes read-only Handla: find online-capable stores by postcode and search a store's online prices. Cart and delivery slots are listed as planned, not done. Its README notes Handla's bot protection can block price lookups for a while.
- **mcp** — `jonasthim/ica-mcp` (see `se-ica`).
- **bot** — hosted Apify actors for ica.se (paid, pay-per-result).

## Data

Store-specific online prices and product search. Order history: not found (unverified whether the web account exposes it).

## FoodSavr mapping

Mostly offers/price enrichment per store. Orders would be a strong inventory input if order history can be read; currently only Kivra receipts are known to carry item detail.

## Risks and constraints

- Bot protection on Handla; private API; ICA terms forbid reverse engineering (per ica-hub README).
- Per-store pricing: prices differ by chosen store.

## Existing work

- https://github.com/jonasthim/ica-mcp
- https://apify.com/studio-amba/ica-scraper

## Sources

- https://github.com/jonasthim/ica-mcp — Handla tools, planned cart, bot protection note
- https://apify.com/studio-amba/ica-scraper — hosted ICA price scraper
