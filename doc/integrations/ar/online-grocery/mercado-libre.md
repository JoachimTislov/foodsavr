---
id: ar-mercado-libre
name: Mercado Libre
scope: ar
category: online-grocery
operator: MercadoLibre, Inc.
access: [api-public, mcp]
auth: oauth2
data: [products, prices, orders]
item_level: true
cost: free
user_base: LatAm (AR, BR, MX, CL, CO...)
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Mercado Libre

Marketplace with an open developer API (items, searches, user data) and an official MCP server. Mostly general retail, not grocery-specific.

## Access

- **api-public** — developers.mercadolibre.com: `/sites/$SITE_ID/search`, `/items/$ITEM_ID`; OAuth `api.mercadolibre.com/oauth/token`; country mirrors.
- **mcp** — official Mercado Libre MCP server (OAuth 2.0), per developer docs.

## Data

Item search by site; seller-oriented user items.

## FoodSavr mapping

Enrichment/price lookup; buyer order history scope unverified.

## Risks and constraints

Seller-focused terms.

## Existing work

- None checked.

## Sources

- https://developers.mercadolibre.com.ar/en_us/items-and-searches — items/search
- https://developers.mercadolibre.com.mx/en_us/mcp-server — MCP server
- https://global-selling.mercadolibre.com/devsite/authentication-and-authorization-global-selling — OAuth
