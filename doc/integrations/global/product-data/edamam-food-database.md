---
id: global-edamam-food-database
name: Edamam Food Database
scope: global
category: product-data
operator: Edamam
access: [api-public]
auth: api-key
data: [nutrition, products]
item_level: true
cost: freemium
user_base: Global; used by many nutrition apps
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Edamam Food Database

Food Database API with 900k+ foods (claims), UPC/EAN lookup, parser for text, nutrient analysis, diet/health labels.

## Access

- **api-public** - `https://api.edamam.com/api/food-database/v2/parser` (app_id/app_key query params); developer free tier with low call limits, paid beyond (verify current plans).

## Data

`parsed`/`hints`: `food.foodId`, `label`, `brand`, `category`, `nutrients`, `measures`; UPC lookup via `upc=`.

## FoodSavr mapping

Nutrition enrichment and text parsing of ingredient lines; separate recipe API in recipes category.

## Risks and constraints

- Free tier restricted to non-commercial/low volume (unverified); attribution required.

## Existing work

- Edamam also offers Nutrition Analysis API.

## Sources

- https://developer.edamam.com/food-database-api - API page
