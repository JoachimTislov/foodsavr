---
id: global-barcode-lookup
name: Barcode Lookup
scope: global
category: product-data
operator: Barcode Lookup (Hungry Hippo / Barcode Lookup Inc.)
access: [api-public]
auth: api-key
data: [products, prices]
item_level: true
cost: paid
user_base: Global; strong US retail coverage (claims 1B+ products, unverified)
tos_risk: low
fit: 2
status: researched
last_verified: 2026-11-21
---

# Barcode Lookup

Commercial barcode API returning name, brand, category, images and store prices. Paid only (free trial limited).

## Access

- **api-public** - `https://api.barcodelookup.com/v3/products?barcode=...&key=...`; paid tiers, plan-based daily limits (unverified).

## Data

`products[]`: `barcode_number`, `title`, `brand`, `category`, `images`, `stores[]` with price.

## FoodSavr mapping

Fallback enrichment and price hints; paid, so low priority vs OFF.

## Risks and constraints

- Paid; redistribution of data restricted by ToS (unverified).

## Existing work

- No MCP server found.

## Sources

- https://www.barcodelookup.com/api - API page
