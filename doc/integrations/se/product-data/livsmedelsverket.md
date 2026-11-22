---
id: se-livsmedelsverket
name: Livsmedelsverket Food Composition API
scope: se
category: product-data
operator: Livsmedelsverket (Swedish Food Agency)
access: [api-public, feed]
auth: none
data: [nutrition, products]
item_level: true
cost: free
user_base: Open government dataset
tos_risk: low
fit: 4
status: researched
last_verified: 2026-11-21
---

# Livsmedelsverket Food Composition API

Official Swedish food composition database: about 2,500 generic foods with over 50 nutrients each. Generic items, not branded products with EAN.

## Access

- **api-public** — Swagger at `dataportal.livsmedelsverket.se/livsmedel/swagger/index.html`; JSON; no auth mentioned. Endpoints: `/api/info`, `/api/v1/livsmedel`, `/api/v1/livsmedel/{nummer}`, `.../naringsvarden`, `.../klassificeringar` (LanguaL, FoodEx2), `.../ravaror`, `.../ingredienser`.
- **feed** — the open-data page also offers the dataset (download format unverified).

## Data

Nutrient values, classifications, raw commodities, retention/weight-change factors.

## FoodSavr mapping

Nutrition enrichment for generic inventory items and recipes; useful for Swedish-named staples.

## Risks and constraints

CC BY 4.0: credit Livsmedelsverket. No branded products or barcodes.

## Existing work

Not reviewed.

## Sources

- https://www.livsmedelsverket.se/en/about-us/open-data/food-composition-data/ — API, endpoints, license
