---
id: jp-rakuten-recipe
name: Rakuten Recipe (Rakuten Web Service)
scope: jp
category: recipes
operator: Rakuten Group
access: [api-public, mcp]
auth: api-key
data: [recipes]
item_level: false
cost: free
user_base: Japan
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Rakuten Recipe (Rakuten Web Service)

Rakuten Web Service provides official recipe category list and ranking APIs under an application ID.

## Access

- **api-public** — webservice.rakuten.co.jp; endpoint e.g. `https://app.rakuten.co.jp/services/api/Recipe/CategoryList/20170426`; app ID; up to 5 apps per developer (community note); branding display required.
- **mcp** — community Rakuten MCP (mrslbt/rakuten-mcp).

## Data

Recipe category tree and ranked recipes with ingredients (field list unverified).

## FoodSavr mapping

Recipes input in Japanese.

## Risks and constraints

Branding obligations; Japanese docs.

## Existing work

- https://mcpservers.org/fr/servers/mrslbt/rakuten-mcp
- https://apify.com/shiokoshi356/rakuten-recipe-scraper

## Sources

- https://webservice.rakuten.co.jp/documentation/recipe-category-list — recipe category API
- https://webservice.rakuten.co.jp/document — portal
- https://mcpservers.org/fr/servers/mrslbt/rakuten-mcp — MCP
