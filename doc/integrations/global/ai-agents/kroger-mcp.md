---
id: global-kroger-mcp
name: Kroger MCP servers (community)
scope: global
category: ai-agents
operator: Community (CupOfOwls and others)
access: [mcp, api-public]
auth: oauth2
data: [products, prices, orders]
item_level: true
cost: free
user_base: Kroger US shoppers
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Kroger MCP servers (community)

Community MCP servers wrapping the Kroger public API: store lookup by ZIP, product search and cart management.

## Access

- **mcp** — CupOfOwls/kroger-mcp (Python FastMCP, MIT, built on the `kroger-api` library; Kroger API credentials needed). Also `@striderlabs/mcp-kroger` (npm; coupons, fuel points, orders) and hosted Pantry Aide.

## Data

Product search results (name, brand, price, size, UPC), stores, cart.

## FoodSavr mapping

Enrichment and cart push for US users; Kroger API itself is the better direct integration (see US scope).

## Risks and constraints

- Early-stage community projects; maintenance unverified.

## Existing work

- As listed.

## Sources

- https://github.com/CupOfOwls/kroger-mcp — server
- https://pypi.org/project/kroger-mcp/ — package
- https://mcp.so/server/pantry-aide/hsearcy — Pantry Aide
