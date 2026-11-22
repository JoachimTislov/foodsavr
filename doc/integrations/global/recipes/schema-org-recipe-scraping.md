---
id: global-schema-org-recipe-scraping
name: schema.org/Recipe scraping (recipe-scrapers)
scope: global
category: recipes
operator: Open standard / community libraries
access: [feed, bot]
auth: none
data: [recipes]
item_level: true
cost: free
user_base: Works on thousands of recipe sites
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# schema.org/Recipe scraping (recipe-scrapers)

Most recipe sites embed schema.org/Recipe JSON-LD. Libraries parse a pasted URL into structured recipe data, enabling 'import recipe from link' without per-site APIs. Used by Mealie and Tandoor.

## Access

- **feed** - fetch the page and read `<script type="application/ld+json">` Recipe object (`recipeIngredient`, `recipeInstructions`, `recipeYield`, `nutrition`).
- Libraries: `recipe-scrapers` (Python, 600+ sites), `recipe-scrapers` ports in other languages; Dart parsing of JSON-LD can be done directly (unverified existing package).
- **bot** - sites without JSON-LD need site-specific HTML scraping.

## Data

`Recipe`: `name`, `image`, `recipeIngredient[]` (free text), `recipeInstructions` (HowToStep), `recipeYield`, `totalTime`, `nutrition`.

## FoodSavr mapping

Recipes input class via share sheet/URL paste; ingredient lines require parsing into quantity/unit/name (ingredient-parser libraries).

## Risks and constraints

- Copyright on recipe text/images: store links and structured facts, not full copies (legal review recommended).
- Sites may block scrapers; fetch on the user's behalf from the device.

## Existing work

- recipe-scrapers (hhursev/recipe-scrapers) on GitHub; Mealie uses it.

## Sources

- https://schema.org/Recipe - schema
- https://github.com/hhursev/recipe-scrapers - Python library
