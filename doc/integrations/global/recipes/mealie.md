---
id: global-mealie
name: Mealie
scope: global
category: recipes
operator: Mealie community (self-hosted)
access: [api-public, mcp]
auth: api-key
data: [recipes, plans, lists]
item_level: true
cost: free
user_base: Popular self-hosted recipe manager (large GitHub following)
tos_risk: low
fit: 4
status: researched
last_verified: 2026-11-21
---

# Mealie

Self-hosted recipe manager with meal planner and shopping lists, REST API with OpenAPI docs and long-lived API tokens. Natural bridge for users who already keep recipes there.

## Access

- **api-public** - per-instance REST API (`/api/recipes`, `/api/households/mealplans`, `/api/households/shopping/lists`, docs at `/docs`); user API tokens as Bearer.
- **mcp** - community: rldiao/mealie-mcp-server (most referenced), amercat37/mealie-mcp-server, PyPI `mcp-mealie`, npm `mealie-mcp`.

## Data

Recipes (schema.org-like), tags, categories, meal plan entries, shopping list items with foods/units.

## FoodSavr mapping

Import recipes and meal plans; push FoodSavr shopping list or missing ingredients into Mealie lists.

## Risks and constraints

- Each user hosts their own instance: base URL + token must be entered by user; instance may be LAN-only.
- Version API changes between major versions (v1 to v2 households).

## Existing work

- MCP servers above; Home Assistant integration exists (unverified).

## Sources

- https://docs.mealie.io/documentation/getting-started/api-usage/ - API usage
- https://github.com/rldiao/mealie-mcp-server - MCP server
- https://pypi.org/project/mcp-mealie/ - MCP server
