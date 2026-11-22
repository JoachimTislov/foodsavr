---
id: au-coles-flybuys
name: Coles (Flybuys)
scope: au
category: grocery-retail
operator: Coles Group / Flybuys
access: [api-private, bot]
auth: session-cookie
data: [products, prices]
item_level: true
cost: free
user_base: Second-largest AU grocer
tos_risk: high
fit: 3
status: researched
last_verified: 2026-11-21
---

# Coles (Flybuys)

No public API. drkno/au-supermarket-apis includes a Coles OpenAPI spec reverse-engineered from apps and web. No Flybuys purchase-history client found.

## Access

- **api-private** — Coles spec in drkno/au-supermarket-apis.
- **bot** — Apify Coles scrapers.

## Data

Products, prices, specials.

## FoodSavr mapping

Enrichment and offers; purchases unavailable.

## Risks and constraints

Flybuys has a bug-bounty policy; do not probe customer data.

## Existing work

- https://github.com/drkno/au-supermarket-apis

## Sources

- https://github.com/drkno/au-supermarket-apis — specs
- https://apify.com/rel8ble/coles-scraper.md — scraper
