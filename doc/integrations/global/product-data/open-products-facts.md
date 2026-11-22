---
id: global-open-products-facts
name: Open Products Facts
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
fit: 2
status: researched
last_verified: 2026-11-21
---

# Open Products Facts

Sister database of Open Food Facts for non-food consumer goods (household, cosmetics-adjacent, electronics). Same server code and API shape as OFF; low relevance for a food app except household items on a receipt.

## Access

- **api-public** - `https://world.openproductsfacts.org/api/v2/product/{barcode}` (same API as OFF; unverified exact paths, mirrors OFF docs).
- **feed** - data dumps published on the site.

## Data

Product name, brand, quantity, images, categories; no nutrition. Coverage is much smaller than OFF.

## FoodSavr mapping

Fallback lookup for non-food barcodes so the item can be classified as non-food and excluded from inventory.

## Risks and constraints

- Same ODbL/CC BY-SA terms as OFF; same User-Agent/rate-limit etiquette (unverified for this domain).

## Existing work

- Same SDKs as OFF where the host is configurable.
- No dedicated MCP server found.

## Sources

- https://world.openproductsfacts.org - project site
- https://openfoodfacts.github.io/openfoodfacts-server/api/ - shared API docs
