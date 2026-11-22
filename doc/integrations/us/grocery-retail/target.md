---
id: us-target
name: Target
scope: us
category: grocery-retail
operator: Target Corporation
access: [api-private, api-partner, bot]
auth: api-key
data: [products, prices]
item_level: true
cost: free
user_base: US-wide
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Target

Target's website uses an internal aggregation API (RedSky). It is usable for product, price and store-availability lookups; no customer purchase API.

## Access

- **api-private** — `redsky.target.com` endpoints documented in a community gist; a key is embedded in public web requests (not recorded here). Target staff reportedly describe it as public (per the gist, unverified).
- **api-partner** — Target partner APIs (OpenAPI listed by API Evangelist) are for suppliers.

## Data

Product (TCIN, UPC), price, promotions, store fulfilment.

## FoodSavr mapping

Enrichment and price lookup only.

## Risks and constraints

Undocumented, may change without notice; ToS unclear.

## Existing work

- https://github.com/nwithan8/TargetAPI — wrapper (unofficial, may be stale)
- https://github.com/doesdev/target-api — older wrapper

## Sources

- https://gist.github.com/LumaDevelopment/f2a34a202fed6ab5a7f3a31282834943 — RedSky endpoints
- https://apis.io/providers/target/ — partner API catalog
