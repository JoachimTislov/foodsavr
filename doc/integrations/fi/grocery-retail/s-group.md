---
id: fi-s-group
name: S-Group (S-kaupat, S-mobiili, Prisma, S-market)
scope: fi
category: grocery-retail
operator: SOK / S Group
access: [api-private, bot]
auth: unknown
data: [products, prices, stores, purchases]
item_level: true
cost: unknown
user_base: Finland's other large grocery group; S-Etukortti loyalty (size unverified)
tos_risk: high
fit: 4
status: researched
last_verified: 2026-11-21
---

# S-Group

S-kaupat (online shop) and S-mobiili (app with bonus card and, per the app, purchase history; unverified here). A community Python wrapper exists for the catalogue side; no consumer purchase-history client found.

## Access

- **api-private** — [sokpy](https://pypi.org/project/sokpy/) (v0.1.8, Sep 2026, repo [Collectseal120/sokpy](https://github.com/Collectseal120/sokpy)): unofficial wrapper for SOK/S-Kaupat APIs: store info, products by id, pricing. Auth not described.
- No official public developer portal found (searches returned none; unverified).
- **bot** — Account-area automation untested.
- **export** — GDPR request for S-Etukortti data (format unverified).
- No MCP server found.

## Data

Stores, products, prices (sokpy). Purchase history in S-mobiili: unverified.

## FoodSavr mapping

Catalogue/price enrichment now; purchases only if an export or app client appears.

## Risks and constraints

Unofficial API may change or be blocked; ToS risk.

## Existing work

sokpy only.

## Sources

- https://pypi.org/project/sokpy/
- https://github.com/Collectseal120/sokpy
