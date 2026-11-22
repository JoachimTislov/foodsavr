---
id: global-nutritionix
name: Nutritionix
scope: global
category: product-data
operator: Nutritionix
access: [api-public, mcp]
auth: api-key
data: [nutrition, products]
item_level: true
cost: paid
user_base: US-centric; natural-language nutrition and branded/restaurant items
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Nutritionix

Nutrition database with natural-language endpoint ('1 cup rice and 2 eggs') and UPC lookup for US branded and restaurant foods. Free developer tier was discontinued per public reports; paid enterprise plans (unverified).

## Access

- **api-public** - `https://trackapi.nutritionix.com/v2/` (`/natural/nutrients`, `/search/instant`, `/search/item?upc=`) with `x-app-id`/`x-app-key` headers.
- **mcp** - community Nutritionix MCP server (MCP-Forge) listed in a directory (unverified maintenance).

## Data

Per-serving full nutrient panel, photos, brand, UPC; natural language parsing to foods.

## FoodSavr mapping

Parsing free-text meals to nutrition for meal plans; US barcodes.

## Risks and constraints

- Pricing/availability of a free tier is uncertain; verify before building.

## Existing work

- Community MCP listed above.

## Sources

- https://developer.nutritionix.com/ - developer portal
- https://mcp.so/tags/nutrition - MCP directory listing
