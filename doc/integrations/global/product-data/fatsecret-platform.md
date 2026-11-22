---
id: global-fatsecret-platform
name: FatSecret Platform API
scope: global
category: product-data
operator: FatSecret
access: [api-public, mcp]
auth: oauth2
data: [nutrition, products, recipes]
item_level: true
cost: freemium
user_base: Global; 1M+ foods, localized in many countries
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# FatSecret Platform API

FatSecret Platform API: food search, barcode (EAN/UPC) lookup, nutrition, recipes, localized per region including Norway. Basic tier is free with attribution; Premier tiers add features (barcode, images, etc. depending on plan - verify).

## Access

- **api-public** - REST at `https://platform.fatsecret.com/rest/` with OAuth 2.0 client-credentials; IP whitelisting required on some plans (unverified); methods `foods.search`, `food.find_id_for_barcode`, `food.get`, `recipes.search`.
- **mcp** - a combined USDA FoodData Central + FatSecret MCP ('Food Facts') appears in glama.ai listings (unverified).

## Data

Food id, brand, servings with macros/micros, region-specific data, images (premier).

## FoodSavr mapping

Barcode and nutrition enrichment with better regional coverage than USDA; also user food-diary APIs (oauth1 user auth) for meal-planning sync.

## Risks and constraints

- Attribution link required on free tier; commercial use needs agreement for some features (unverified).

## Existing work

- Community wrappers on GitHub (unverified).

## Sources

- https://platform.fatsecret.com/api/ - API docs
- https://glama.ai/mcp/servers/p8qt790pgq - MCP directory entry
