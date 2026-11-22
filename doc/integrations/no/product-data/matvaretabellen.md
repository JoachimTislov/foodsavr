---
id: no-matvaretabellen
name: Matvaretabellen (Norwegian Food Composition Table)
scope: no
category: product-data
operator: Norwegian Food Safety Authority (Mattilsynet) and Norwegian Directorate of Health
access: [api-public, feed]
auth: none
data: [nutrition]
item_level: false
cost: free
user_base: Public Norwegian reference table; generic foods (no barcodes)
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Matvaretabellen (Norwegian Food Composition Table)

Norway's official food composition database: generic foods (not branded products, no EAN) with nutrient values per 100 g and food groups. Useful for nutrition of Norwegian staples and category mapping. Placed under `no` as an allowed exception to the global product-data assignment.

## Access

- **api-public** - static JSON/EDN endpoints: `https://www.matvaretabellen.no/api/{nb|en}/foods.json`, `food-groups.json`, `nutrients.json`, `sources.json`, plus `/api/langual.json`. No auth. APIs are unversioned with backward compatibility aimed for.
- **feed** - data is updated once a year in autumn, so it can be cached or bundled locally.

## Data

Foods reference food groups, nutrient definitions (EuroFIR classification) and sources by id; LanguaL classification codes. Field-level schema not captured here; see the API page.

## FoodSavr mapping

Enrichment for generic items without barcode (e.g. 'melk, lett'): nutrition and food-group mapping. Cannot match branded products by EAN.

## Risks and constraints

- No formal licence stated on the API page; it asks users to credit Matvaretabellen as the source.
- Generic foods only; Norwegian/English names.

## Existing work

- Source code on GitHub (matvaretabellen-deux), linked from the API page.

## Sources

- https://www.matvaretabellen.no/api/ - API docs
