---
id: global-open-food-facts-mcp
name: Open Food Facts MCP servers (community)
scope: global
category: ai-agents
operator: Community
access: [mcp, api-public]
auth: none
data: [products, nutrition]
item_level: true
cost: free
user_base: community projects
tos_risk: low
fit: 4
status: researched
last_verified: 2026-11-21
---

# Open Food Facts MCP servers (community)

No official Open Food Facts MCP server found; several community ones wrap its free API for barcode lookup, nutrition, allergens and eco-score.

## Access

- **mcp** — e.g. JagjeevanAK/OpenFoodFacts-MCP (also GitHub issue tools), `openfoodfacts-mcp-server` on PyPI (no API key), `openfoodfacts-mcp` on npm, `mcp-open-food-facts`.

## Data

Product by EAN, nutrition facts, Nutri-Score, allergens, search.

## FoodSavr mapping

Enrichment by EAN; FoodSavr can call the Open Food Facts API directly (see product-data scope) and use MCP only for agent features.

## Risks and constraints

- Maintenance unverified.

## Existing work

- Listed.

## Sources

- https://pypi.org/project/openfoodfacts-mcp-server — Python server
- https://github.com/JagjeevanAK/OpenFoodFacts-MCP — repo
- https://mcp.so/servers/openfoodfacts-mcp — listing
