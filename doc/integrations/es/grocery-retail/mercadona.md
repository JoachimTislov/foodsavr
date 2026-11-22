---
id: es-mercadona
name: Mercadona
scope: es
category: grocery-retail
operator: Mercadona SA
access: [api-private, bot]
auth: none
data: [products, prices, nutrition]
item_level: true
cost: free
user_base: Spain #1 grocer; online shop in many provinces
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# Mercadona

Spain's largest supermarket. No official API; the web shop's REST endpoints (tienda.mercadona.es/api) for categories, products and product detail are widely wrapped.

## Access

- **api-private** — unauthenticated product/category endpoints (documented by MercaEx); a public search index is also referenced there (credentials not recorded here).
- **bot** — Apify scrapers by postal code; `mercadona-cli` replays a logged-in HAR.

## Data

Product name, price, unit price, packaging, categories, nutrition (via `mercaapi`), price history (via `mercaapi`).

## FoodSavr mapping

Enrichment and prices; account order history only via logged-in session (`mercadona-cli`).

## Risks and constraints

Unofficial; postal code required for catalogue. Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR.

## Existing work

`m0wer/mercaapi` (products, nutrition, price history API), `jtayped/mercapy` (Python), `ivorpad/mercadona-cli` (Go), `merca_ex` (Elixir), Apify scrapers.

## Sources

- https://readme.hex.pm/merca_ex/0.1.0 — endpoint documentation
- https://github.com/jtayped/mercapy — Python client
- https://awesome.ecosyste.ms/projects/github.com%2Fm0wer%2Fmercaapi — products API
- https://mintlify.wiki/ivorpad/mercadona-cli — CLI
- https://apify.com/abotapi/mercadona-es-scraper — scraper
- https://glama.ai/mcp/servers/lu2l2fiila — MCP listing (verify it is Mercadona-related)
