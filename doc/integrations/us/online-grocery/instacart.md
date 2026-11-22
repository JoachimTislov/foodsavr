---
id: us-instacart
name: Instacart (Developer Platform)
scope: us
category: online-grocery
operator: Maplebear Inc. (Instacart)
access: [api-public, api-partner, mcp]
auth: api-key
data: [lists, recipes, products]
item_level: true
cost: free
user_base: US and Canada, millions of households
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Instacart (Developer Platform)

Instacart Developer Platform lets apps create shoppable recipe and shopping-list pages that open in Instacart (web/app deep link). It is write-out only; it does not return a user's order history.

## Access

- **api-public** — docs.instacart.com/developer_platform_api. `POST /idp/v1/products/products_link` creates a shopping-list or recipe page and returns a shareable URL (expiry up to 365 days). API key issued by Instacart; one key may cover only one endpoint. Canada: key via Instacart rep (per a Canadian-market summary).
- **mcp** — official Instacart MCP server (docs.instacart.com/mcp_servers): store availability, recipe-ingredient lookup, assemble/modify orders. Auth not stated on that page.
- A community `mcp-instacart` uses Playwright against a logged-in session (unofficial).

## Data

Request: title, image, link_type, expiry, line items (name, quantity, unit, filters). Response: URL, plus `partner_linkback_url` for recipes.

## FoodSavr mapping

Outbound only: FoodSavr shopping list or meal-plan recipe becomes an Instacart cart link (`lists`, `recipes`). No purchase inflow; returned URL cannot confirm what was bought.

## Risks and constraints

Partner agreement and branding requirements likely; keys are issued by Instacart (unverified specifics). Browser-automation MCP routes break ToS risk.

## Existing work

- https://github.com/markswendsen-code/mcp-instacart — Playwright MCP (unofficial)
- https://github.com/api-evangelist/instacart — API catalog

## Sources

- https://docs.instacart.com/developer_platform_api — official docs
- https://docs.instacart.com/developer_platform_api/api/products/create_shopping_list_page — shopping list endpoint
- https://docs.instacart.com/mcp_servers/ — official MCP
- https://company.instacart.com/business/developers — programme page
