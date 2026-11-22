---
id: no-tine-oppskrifter
name: Tine oppskrifter
scope: no
category: recipes
operator: TINE SA
access: [bot, feed]
auth: none
data: [recipes, nutrition]
item_level: true
cost: free
user_base: Large Norwegian audience (unverified)
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Tine oppskrifter

Dairy cooperative's recipe site; no API or scraper support found (unverified).

## Access

- **bot/feed** — no official developer API found. Recipe pages publish schema.org `Recipe` data, parsed by the open-source `recipe-scrapers` library for supported sites (per its docs). Scraping is the only access.
- Not confirmed in recipe-scrapers list (unverified); generic schema.org parsing may still work.

## Data

Title, ingredients (Norwegian text), steps, servings, times; nutrition if marked up. Ingredients are free text, no EAN.

## FoodSavr mapping

Recipes -> meal plans and shopping lists; match ingredients to inventory by name. Import by URL (share-sheet) is the lightest path.

## Risks and constraints

- Content copyright; storing full recipes may need permission (unverified).
- Scraping volume limits; maintainers of recipe-scrapers ask for low traffic.

## Existing work

- [hhursev/recipe-scrapers](https://github.com/hhursev/recipe-scrapers) — Python scraper library.

## Sources

- [recipe-scrapers on PyPI](https://pypi.org/project/recipe-scrapers/) — supported sites list.
