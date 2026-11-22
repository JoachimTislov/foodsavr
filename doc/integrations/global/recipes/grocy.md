---
id: global-grocy
name: Grocy
scope: global
category: recipes
operator: Grocy (Bernd Bestel, open source, self-hosted)
access: [api-public, mcp]
auth: api-key
data: [inventory, products, lists, recipes, plans]
item_level: true
cost: free
user_base: Large self-hosted household ERP community; Home Assistant integration
tos_risk: low
fit: 5
status: researched
last_verified: 2026-11-21
---

# Grocy

Self-hosted groceries and household management: stock with best-before dates, locations, shopping lists, recipes with stock fulfilment, meal plan, barcodes, chores. Closest functional analogue to FoodSavr; users can sync inventory both ways.

## Access

- **api-public** - every Grocy instance exposes a REST API with Swagger at `/api` (`/stock`, `/stock/products/{id}/add|consume`, `/objects/products`, `/objects/shopping_list`, `/recipes`, meal plan); auth via `GROCY-API-KEY` header (keys created in the UI).
- **mcp** - several community servers: miguelangel-nubla/mcp-grocy, saya6k/mcp-grocy-api (Home Assistant add-on), johndoyle/grocy-mcp-server, rusty4444/grocy-mcp, moustafattia/grocy-mcp (PyPI `grocy-mcp`), anishanilkumar/grocy-mcp.

## Data

Stock entries with `amount`, `best_before_date`, `location_id`, `price`, `purchased_date`, product barcodes, quantity units and conversions; shopping list; recipes with fulfilment.

## FoodSavr mapping

Bidirectional inventory sync: Grocy stock <-> FoodSavr items with expiry; import shopping list and recipes; barcodes enable matching. Fit is high because data is item-level with expiry.

## Risks and constraints

- User-hosted: URL and API key must be entered; often LAN-only (needs VPN/reverse proxy).
- Grocy has no OAuth; API key grants full access.
- Data model differences (units, product hierarchy).

## Existing work

- MCP servers above; Home Assistant Grocy integration; Grocy mobile apps (e.g. Grocy Android, unverified).

## Sources

- https://grocy.info/ - project site
- https://github.com/grocy/grocy - source and API docs
- https://pypi.org/project/grocy-mcp/0.2.0/ - MCP server
- https://unpkg.com/mcp-grocy-api@1.4.13/README.md - MCP server README
