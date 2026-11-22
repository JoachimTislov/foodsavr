---
id: global-recipe-mcp
name: Recipe and meal-planning MCP servers (Mealie etc.)
scope: global
category: ai-agents
operator: Community
access: [mcp, api-public]
auth: api-key
data: [recipes, plans, lists]
item_level: true
cost: free
user_base: self-hosted Mealie users
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Recipe and meal-planning MCP servers (Mealie etc.)

Community MCP servers connect assistants to a user's self-hosted Mealie instance for recipes, meal plans and shopping lists.

## Access

- **mcp** — rldiao/mealie-mcp-server (Python), `mcp-mealie` (PyPI), `@ni-c/mealie-mcp` (npm). Each needs the user's Mealie base URL and API token. Mealie's own REST API is the direct route.

## Data

Recipes, meal plan entries, shopping lists.

## FoodSavr mapping

`recipes`/`plans`/`lists`; direct Mealie API better for FoodSavr.

## Risks and constraints

- The rldiao HTTP transport has no built-in authentication.

## Existing work

- As listed.

## Sources

- https://github.com/rldiao/mealie-mcp-server — repo
- https://pypi.org/project/mcp-mealie/ — package
