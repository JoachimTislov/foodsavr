---
id: no-vinmonopolet
name: Vinmonopolet API
scope: no
category: prices-offers
operator: AS Vinmonopolet (state alcohol retailer)
access: [api-public, mcp]
auth: api-key
data: [products, prices, offers]
item_level: true
cost: free
user_base: Every Norwegian wine/spirits buyer; relevant only for alcohol items
tos_risk: low
fit: 2
status: researched
last_verified: 2026-11-21
---

# Vinmonopolet API

Vinmonopolet runs an official developer portal. The Open product needs only registration and acceptance of the API terms. FoodSavr gets product details and store data for alcohol (wine, beer, spirits), which no grocery chain sells.

## Access

- **api-public** — portal `https://api.vinmonopolet.no`; register, subscribe to the "Open" product, send the subscription key in the `Ocp-Apim-Subscription-Key` header. Open product contains Products (v0) and Stores (v0). Press and Restricted (wholesaler) products exist but need approval; not usable for FoodSavr.
- **mcp** — community "Polvenn" MCP (beer releases, stock check, nearby stores) on npm as `@henrikogard/polvenn-mcp-server`; uses the official API with a web fallback. Repo URL unconfirmed.
- Contacts: api@vinmonopolet.no (technical).

## Data

Products API operations: product details, half-yearly sales in litres per store per product group, monthly sales per article. Stores API: store list (a community library says about 126 stores, no pagination, unverified). Community clients (`vinmonopolet-ts`) also expose stock and prices.

## FoodSavr mapping

Enrichment/products for alcohol (name, volume, category, price). Not purchase history: Vinmonopolet loyalty/receipt data has no known access.

## Risks and constraints

- Terms must be accepted at the portal; check redistribution and rate limits there (not stated in the sources fetched).
- Subscription key is per developer: keep server-side.

## Existing work

- [vinmonopolet-ts](https://app.unpkg.com/vinmonopolet-ts@5.2.12/files/README.md) — npm client.
- Polvenn MCP server (above).

## Sources

- https://www.vinmonopolet.no/om-oss/presse/datadeling — API tiers, access rules
- https://api.vinmonopolet.no — developer portal
- https://app.unpkg.com/vinmonopolet-ts@5.2.12/files/README.md — client library
- https://glama.ai/mcp/servers/henrikogaard/mcp-polvenn — MCP listing
