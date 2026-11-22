---
id: se-primat
name: Primat (Swedish grocery price API)
scope: se
category: prices-offers
operator: primat.nu (entity unverified)
access: [api-public, feed]
auth: api-key
data: [prices, offers, products]
item_level: true
cost: freemium
user_base: Developer-facing price API; small
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Primat (Swedish grocery price API)

Third-party API with daily prices per store from ICA, Coop, Willys, Hemköp, Lidl and City Gross (2,837 stores, 214,388 products as of 2026-11-07).

## Access

- **api-public** — base `https://primat.nu/api/v3`, OpenAPI at `/api/v3/openapi.json`. Bearer or `X-API-Key`. A one-hour test key via POST `/signup` with an email; then a 30-day trial that requires a card. Python client and examples on GitHub (MIT).
- Endpoints: `/stores`, `/stores/resolve`, `/products`, `/prices` (cursor paged, `offers=1`), `/deals`, `/cheap`, `/batch`, `/history/...` (by product or GTIN; full history on paid plans).
- **feed** — "Synk" to SQLite/DuckDB/Postgres/Parquet on Pro and Business plans.

## Data

GTIN/EAN as cross-store key (null if the chain publishes none), regular, member, multi-price, comparison price, offer, previous price, category, timestamps.

## FoodSavr mapping

EAN lookup for enrichment, price drops and deals for shopping lists, offers per user's store.

## Risks and constraints

Data is not open: apps (commercial too) allowed; reselling or exposing it as a price API is forbidden. Paid plans for history and sync. Young service (history since 2025-12); long-term stability unknown.

## Existing work

- https://github.com/ostwilkens/primat-api (client and OpenAPI)

## Sources

- https://raw.githubusercontent.com/ostwilkens/primat-api/HEAD/README.md — endpoints, fields, auth, terms
