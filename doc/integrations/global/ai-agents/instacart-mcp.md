---
id: global-instacart-mcp
name: Instacart MCP server (official)
scope: global
category: ai-agents
operator: Instacart
access: [mcp, api-partner]
auth: oauth2
data: [orders, products]
item_level: true
cost: unknown
user_base: Instacart US/Canada grocery users
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Instacart MCP server (official)

Instacart publishes an MCP server that lets assistants check which stores fulfil an order, find retailer inventory for a recipe's ingredients, and add, swap or remove products and track the current order. Primarily for building carts, not reading order history.

## Access

- **mcp** — documented at docs.instacart.com/mcp_servers/ (last updated 2026-05-14); endpoint, auth and regions not stated on the overview page: see the get-started guide.

## Data

Store availability, product matches, cart/order state.

## FoodSavr mapping

Outbound: push FoodSavr shopping lists or recipe ingredients to an Instacart cart. Order history reading not confirmed.

## Risks and constraints

- Region limited (US/Canada, unverified); terms in Instacart developer docs.

## Existing work

- Community alternative: Strider Labs `@striderlabs/mcp-instacart` (browser-automation based; CAPTCHA risks).

## Sources

- https://docs.instacart.com/mcp_servers/ — official MCP docs
- https://github.com/markswendsen-code/mcp-instacart — community server
