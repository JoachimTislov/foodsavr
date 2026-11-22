---
id: global-edamam-recipe-search
name: Edamam Recipe Search API
scope: global
category: recipes
operator: Edamam
access: [api-public]
auth: api-key
data: [recipes, nutrition]
item_level: true
cost: freemium
user_base: Global; 2M+ recipes indexed from web (claims)
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Edamam Recipe Search API

Recipe search API over web-sourced recipes with diet/health filters, nutrition per recipe and links to the source sites. Returns metadata and links, not full instructions.

## Access

- **api-public** - `https://api.edamam.com/api/recipes/v2` with `app_id`/`app_key`; free developer tier with low limits, paid above (verify).

## Data

`hits[].recipe`: `label`, `image`, `url`, `source`, `ingredientLines`, `ingredients` (food, quantity, measure, foodId), `totalNutrients`, `healthLabels`, `dietLabels`.

## FoodSavr mapping

Recipe suggestions linking out; ingredient `foodId` links to Edamam Food DB.

## Risks and constraints

- Instructions are on source sites; attribution and display rules apply.

## Existing work

- None specific.

## Sources

- https://developer.edamam.com/edamam-recipe-api - API page
