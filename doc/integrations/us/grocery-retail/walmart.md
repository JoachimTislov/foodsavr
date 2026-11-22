---
id: us-walmart
name: Walmart (US)
scope: us
category: grocery-retail
operator: Walmart Inc.
access: [api-partner, export, bot]
auth: oauth2
data: [products, prices]
item_level: true
cost: partner
user_base: ~100M+ weekly US shoppers (unverified)
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Walmart (US)

Walmart's developer portal serves Marketplace sellers, advertisers (Walmart Connect) and affiliates. No consumer grocery order-history or shopping API for third-party apps was found.

## Access

- **api-partner** — developer.walmart.com: Marketplace APIs (OAuth 2.0, 15 min tokens; Item Search by UPC/GTIN/EAN via `GET /v3/items/walmart/search`) are for sellers. Walmart Connect ads APIs restricted to partners.
- **api-partner** — Affiliate programme gives product feed/links via a network (details unverified).
- **export** — account data download for purchase history (not verified).
- **bot** — hosted/OSS scrapers for product data only.

## Data

Seller-side item data, ad reports, affiliate product feed. No customer receipts.

## FoodSavr mapping

At best enrichment/offers via affiliate feed; purchases would need browser automation of walmart.com order history (unverified).

## Risks and constraints

Marketplace API credentials only for registered sellers; scraping contradicts site terms. A Walmart MCP listing exists but maintainer is unclear (unverified).

## Existing work

- Korean directory entry of a Walmart MCP server (unverified source).

## Sources

- https://developer.walmart.com/us-marketplace/docs/item-search-for-the-walmart-catalog — Item Search API
- https://developer.walmart.com/advertising-partners — Walmart Connect restricted
- https://affiliates.walmart.com/terms — affiliate terms
