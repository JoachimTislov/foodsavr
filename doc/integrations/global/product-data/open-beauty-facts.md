---
id: global-open-beauty-facts
name: Open Beauty Facts
scope: global
category: product-data
operator: Open Food Facts association
access: [api-public, feed]
auth: none
data: [products]
item_level: true
cost: free
user_base: Small; sister project of OFF
tos_risk: low
fit: 1
status: researched
last_verified: 2026-11-21
---

# Open Beauty Facts

Cosmetics counterpart of Open Food Facts (ingredients INCI). Not relevant to food inventory beyond filtering non-food barcodes.

## Access

- **api-public** - `https://world.openbeautyfacts.org/api/v2/product/{barcode}` (same API as OFF; unverified exact paths).
- **feed** - data dumps on the site.

## Data

Name, brand, INCI ingredients, images.

## FoodSavr mapping

Optional: classify scanned barcodes as cosmetics (not food).

## Risks and constraints

- Same ODbL terms as OFF.

## Existing work

- None specific; use OFF SDKs with a different host.

## Sources

- https://world.openbeautyfacts.org - project site
- https://openfoodfacts.github.io/openfoodfacts-server/api/ - shared API docs
