---
id: au-woolworths-au
name: Woolworths (Everyday Rewards)
scope: au
category: grocery-retail
operator: Woolworths Group
access: [api-private, export, bot]
auth: session-cookie
data: [products, prices, purchases, line-items]
item_level: true
cost: free
user_base: Largest AU grocer; Everyday Rewards millions of members
tos_risk: high
fit: 4
status: researched
last_verified: 2026-11-21
---

# Woolworths (Everyday Rewards)

No public API. The website JSON endpoints are reverse-engineered; e-receipts reachable via the Everyday Rewards account.

## Access

- **api-private** — OpenAPI specs from drkno/au-supermarket-apis (reverse engineered); Glama MCP doc of product search/cart endpoints.
- **bot** — Apify scrapers; wooliesR e-receipt scraper (ekutilov).
- **export** — Everyday Rewards e-receipts (unverified format).

## Data

Products/prices; e-receipt lines (author notes rewards API is closed).

## FoodSavr mapping

Receipts to `LineItem` if scraped; product barcodes in some scrapers (unverified).

## Risks and constraints

Private API/ToS risk.

## Existing work

- https://github.com/drkno/au-supermarket-apis
- https://github.com/ekutilov/wooliesR
- https://github.com/MattTimms/up_woolies
- https://github.com/elijah-g/Woolworths-mcp (listed on Glama)

## Sources

- https://github.com/drkno/au-supermarket-apis — Coles/Woolworths specs
- https://github.com/ekutilov/wooliesR — e-receipt scraping
- https://github.com/MattTimms/up_woolies — Everyday Rewards PoC
- https://apify.com/dromb/woolworths-au-product-search-catalog-unofficial.md — scraper
