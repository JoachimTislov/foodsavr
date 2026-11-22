---
id: global-tandoor
name: Tandoor Recipes
scope: global
category: recipes
operator: Tandoor community (self-hosted)
access: [api-public, mcp]
auth: api-key
data: [recipes, plans, lists, inventory]
item_level: true
cost: free
user_base: Self-hosted recipe manager; active open-source community
tos_risk: low
fit: 4
status: researched
last_verified: 2026-11-21
---

# Tandoor Recipes

Self-hosted recipe manager with meal plans, shopping lists, and a pantry/food-on-hand concept. REST API with Swagger docs.

## Access

- **api-public** - per-instance REST API under `/api/` (recipes, meal-plan, shopping-list-entry, food) with token or OAuth2; docs at `/docs/api/` on the instance.
- **mcp** - starbuck93/tandoor-mcp-server (early stage), mc-mario/tandoor-mcp (recipes and meal plans).

## Data

Recipes with steps/ingredients (food, unit, amount), keywords, meal plans, shopping entries, food 'on hand' flag.

## FoodSavr mapping

Recipes and meal-plan sync; 'on hand' maps to inventory presence.

## Risks and constraints

- Self-hosted: user supplies URL and token; API is versioned loosely.

## Existing work

- MCP servers above.

## Sources

- https://docs.tandoor.dev/features/api/ - API docs
- https://glama.ai/mcp/servers/@mc-mario/tandoor-mcp - MCP server
