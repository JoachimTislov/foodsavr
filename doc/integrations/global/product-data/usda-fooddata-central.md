---
id: global-usda-fooddata-central
name: USDA FoodData Central
scope: global
category: product-data
operator: US Department of Agriculture
access: [api-public, mcp, feed]
auth: api-key
data: [nutrition, products]
item_level: true
cost: free
user_base: Public US government dataset; global use for generic foods
tos_risk: low
fit: 4
status: researched
last_verified: 2026-11-21
---

# USDA FoodData Central

USDA's food composition database: Foundation Foods, SR Legacy, FNDDS and Branded Foods (GTIN/UPC with label nutrition). Strong for generic ingredient nutrition and US branded items.

## Access

- **api-public** - `https://api.nal.usda.gov/fdc/v1/` (`/foods/search`, `/food/{fdcId}`, `/foods`); free key via api.data.gov. Default limit reported as 1,000 requests/hour per key (third-party write-up; verify in docs).
- **feed** - full CSV/JSON downloads (public domain, CC0).
- **mcp** - community servers: FelipeAdachi/mcp-food-data-central, jlfwong/food-data-central-mcp-server, spyrosbou/usda-mcp, zen-apps/mcp-nutrition-tools.

## Data

Branded foods carry `gtinUpc`, `brandOwner`, `ingredients`, `servingSize`, `labelNutrients`. Foundation/SR give per-100 g nutrients for generic foods (e.g. 'milk, whole').

## FoodSavr mapping

Enrichment: nutrition for generic items (no barcode) and US barcodes. Weak outside US for branded products.

## Risks and constraints

- Data is CC0; API key must stay out of client code (proxy through backend or Cloud Function) (recommendation).
- Branded coverage is US only.

## Existing work

- Community MCP servers listed above.

## Sources

- https://fdc.nal.usda.gov/api-guide - official API guide
- https://fdc.nal.usda.gov/download-datasets - bulk downloads
- https://mcpservers.org/servers/FelipeAdachi/mcp-food-data-central - MCP directory
- https://glama.ai/mcp/servers/@jlfwong/food-data-central-mcp-server/tree - MCP directory
