---
id: global-upcitemdb
name: UPCitemdb
scope: global
category: product-data
operator: Blueberry Software / UPCitemdb
access: [api-public]
auth: api-key
data: [products]
item_level: true
cost: freemium
user_base: Global UPC/EAN lookup, strongest in US
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# UPCitemdb

Barcode lookup API with a free trial endpoint and paid plans. Returns title, brand, images, online offers for UPC/EAN.

## Access

- **api-public** - free trial endpoint `https://api.upcitemdb.com/prod/trial/lookup?upc=` (IP rate-limited, about 100 requests/day per docs - verify); paid endpoint `/prod/v1/lookup` with `user_key` header and higher limits.

## Data

`items[]`: `ean`, `title`, `brand`, `category`, `images`, `offers` (merchant prices), `weight`, `dimension`. No nutrition.

## FoodSavr mapping

Fallback product-name enrichment when OFF has no hit; offers array could hint at prices (US).

## Risks and constraints

- Trial limits are low; paid plan required for production.
- Data is general merchandise, quality varies for food outside US.

## Existing work

- No MCP server found.

## Sources

- https://www.upcitemdb.com/wp/docs/main/development/ - API docs
