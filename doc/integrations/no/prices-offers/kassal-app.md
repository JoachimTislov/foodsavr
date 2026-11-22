---
id: no-kassal-app-prices
name: Kassal.app price API
scope: no
category: prices-offers
operator: Kassalapp (Bergen; legal entity unverified)
access: [api-public, mcp]
auth: api-key
data: [prices, products, nutrition, offers]
item_level: true
cost: freemium
user_base: unknown
tos_risk: low
fit: 4
status: researched
last_verified: 2026-11-21
---

# Kassal.app price API

Norwegian grocery price comparison with a documented public REST API: products by EAN, prices per store/chain, price history, nutrition and physical store lookup. Useful for enrichment and price/offer lookups on items already in FoodSavr. The same service's shopping-list side is covered in `../shopping-lists/kassalapp.md`.

## Access

- **api-public** — base `https://kassal.app/api/v1`, bearer API key created in the user profile (auth scheme from a community guide; unverified against official docs). Endpoints: `GET /physical-stores`, `GET /products`, `GET /products/id/{id}`, `GET /products/ean/{ean}`, `GET /products/find-by-url/single|compare`, `POST /products/prices-bulk` (up to 100 EANs, price history).
- Plans: Hobby free (60 req/min, no commercial use, 90 days history); Bedrift 750 NOK/month or 9 000 NOK/year excl. VAT (no rate limit, commercial use, 365 days history).
- **mcp** — "Kassalapp Connector" listed on MCP Market (product search, EAN/URL price comparison, history, shopping lists). Repository and author not confirmed.

## Data

EAN-keyed products with name, brand, vendor, category, per-store current price and history, nutrition, store locations. Prices refresh daily from about 09:00; cache about 6 hours. Some older Rema 1000, Kiwi and Coop prices may be stale (check date per price).

## FoodSavr mapping

Enrichment: resolve EAN from receipts/barcodes to name, category, nutrition. Offers: cheapest-store hints for shopping lists. Does not supply purchases or expiry.

## Risks and constraints

- Free tier forbids commercial use: a FoodSavr product likely needs the Bedrift plan.
- Caching and local storage allowed; credit not required.
- API key per developer, not per end user: keep it server-side (Cloud Functions).

## Existing work

- Kassalapp Connector MCP (listing only).
- Community Node.js guide on kassal.app.

## Sources

- https://kassal.app/api — endpoints, plans, caching terms
- https://kassal.app/api/guides/nodejs — Node guide (auth example)
- https://mcpmarket.com/server/kassalapp-connector — MCP listing
