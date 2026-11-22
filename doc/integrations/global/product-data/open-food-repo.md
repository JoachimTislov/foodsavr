---
id: global-open-food-repo
name: Open Food Repo
scope: global
category: product-data
operator: BLV / FSVO (Swiss Federal Food Safety and Veterinary Office)
access: [api-public, feed]
auth: api-key
data: [products, nutrition]
item_level: true
cost: free
user_base: Swiss product data; small user base
tos_risk: low
fit: 2
status: researched
last_verified: 2026-11-21
---

# Open Food Repo

Swiss open repository of food product data (barcode, ingredients, nutrition, images) contributed by retailers/producers. Relevant for CH; limited elsewhere.

## Access

- **api-public** - REST API on `https://www.foodrepo.org/api/v3/` with API key (free registration); data download available (unverified details).

## Data

Products by barcode: `name_translations`, `ingredients_translations`, `nutrients`, `images`, `country`.

## FoodSavr mapping

Swiss barcode enrichment fallback.

## Risks and constraints

- Terms: Open Data license; registration required (unverified).

## Existing work

- Swiss open-data community clients (unverified).

## Sources

- https://www.foodrepo.org/en/api-docs/swaggers/v3 - API docs
