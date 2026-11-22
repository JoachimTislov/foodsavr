---
id: global-ean-search
name: EAN-Search
scope: global
category: product-data
operator: EAN-Search.org (Relaxed Communications)
access: [api-public, feed]
auth: api-key
data: [products]
item_level: true
cost: freemium
user_base: Global EAN database (claims 100M+ codes, unverified)
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# EAN-Search

Barcode database with name, category and issuing country for EAN/UPC/ISBN. Strong EU/global EAN coverage; useful for European barcodes.

## Access

- **api-public** - `https://api.ean-search.org/api?token=...&op=barcode-lookup&ean=...&format=json`; free tier of limited requests/month (verify), paid plans above.
- **feed** - full database download for paid customers (unverified).

## Data

`name`, `categoryId`, `categoryName`, `issuingCountry`; no nutrition.

## FoodSavr mapping

Name/category fallback for EU barcodes; the issuing country helps classify origin.

## Risks and constraints

- Free tier is small; paid for production.

## Existing work

- Official client libraries for several languages on site.

## Sources

- https://www.ean-search.org/ean-database-api.html - API docs
