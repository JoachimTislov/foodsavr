---
id: no-kassalapp
name: Kassalapp
scope: no
category: shopping-lists
operator: Kassalapp (unverified)
access: [api-public]
auth: api-key
data: [lists, products, prices, offers]
item_level: true
cost: freemium
user_base: Norwegian grocery-price/shopping-list app; size unknown
tos_risk: low
fit: 4
status: researched
last_verified: 2026-11-21
---

# Kassalapp

Norwegian app combining grocery price comparison, barcode lookup and shopping lists. Documented API at kassal.app/docs/api; community Python client supports shopping lists and product search.

## Access

- **api-public** — API documentation at https://kassal.app/docs/api (endpoints, auth and rate limits not confirmed here; token auth assumed, unverified).

## Data

Shopping lists, products (including EAN), prices across Norwegian chains. Endpoint shapes unverified.

## FoodSavr mapping

Lists sync with FoodSavr shopping lists; price/EAN lookup is enrichment. Overlaps with prices-offers and product-data entries by other agents.

## Risks and constraints

- Terms and rate limits to be checked before use.

## Existing work

- [bendikrb/kassalappy](https://awesome.ecosyste.ms/projects/github.com%2Fbendikrb%2Fkassalappy) — Python client with CLI, lists and product search.

## Sources

- [kassalappy on ecosyste.ms](https://awesome.ecosyste.ms/projects/github.com%2Fbendikrb%2Fkassalappy) — client referencing official docs.
- [Kassal docs](https://kassal.app/docs/api) — official docs (not fetched).
