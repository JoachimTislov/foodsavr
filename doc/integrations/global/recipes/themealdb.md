---
id: global-themealdb
name: TheMealDB
scope: global
category: recipes
operator: TheMealDB
access: [api-public]
auth: api-key
data: [recipes]
item_level: false
cost: freemium
user_base: Hobby/community recipe DB, ~300 meals (unverified)
tos_risk: low
fit: 2
status: researched
last_verified: 2026-11-21
---

# TheMealDB

Small open recipe database with a free test key and a paid supporter key. Recipes with ingredients, measures, instructions, YouTube link and thumbnails.

## Access

- **api-public** - `https://www.themealdb.com/api/json/v1/{key}/` (`search.php`, `filter.php?i=ingredient`, `lookup.php?i=id`, `random.php`); free test key documented for development, paid key for production use.

## Data

`meals[]`: `strMeal`, `strCategory`, `strArea`, `strInstructions`, `strMealThumb`, `strYoutube`, `strIngredient1..20` and `strMeasure1..20`.

## FoodSavr mapping

Low-volume recipe inspiration and filter-by-ingredient; limited catalogue.

## Risks and constraints

- Free key is for testing; commercial app needs supporter key.

## Existing work

- Many wrappers on GitHub.

## Sources

- https://www.themealdb.com/api.php - API docs
