---
id: se-koket
name: Köket.se
scope: se
category: recipes
operator: unknown
access: [bot]
auth: none
data: [recipes]
item_level: true
cost: free
user_base: Large Swedish recipe site (size unverified)
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Köket.se

Swedish recipe site. No official API found.

## Access

- **bot** — a commercial Thunderbit template scrapes köket.se recipe pages. Support in `recipe-scrapers` was not confirmed; schema.org/Recipe JSON-LD presence not verified (unverified).
- Alternative: ReceptAPI (receptapi.se, third party, Swedish recipes with ingredients and EU allergens; terms unchecked).

## Data

Recipes with ingredients, steps, servings.

## FoodSavr mapping

Recipe import by URL (share sheet) is the lowest-risk path.

## Risks and constraints

Copyright; scraping terms unreviewed.

## Existing work

- https://github.com/hhursev/recipe-scrapers (generic)

## Sources

- https://thunderbit.com/template/koket-recipe-scraper — scraper template
- https://www.freepublicapis.com/receptapi — ReceptAPI listing
