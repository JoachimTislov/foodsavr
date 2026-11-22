---
id: de-chefkoch
name: Chefkoch
scope: de
category: recipes
operator: Chefkoch GmbH (Gruner+Jahr / RTL Deutschland)
access: [bot, feed]
auth: none
data: [recipes]
item_level: true
cost: free
user_base: Germany's largest recipe site, tens of millions of monthly visits
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Chefkoch

Large German recipe community. No official API found. Recipe pages carry schema.org Recipe markup (unverified), which `recipe-scrapers` parses.

## Access

- **bot** — recipe-scrapers supports chefkoch.de (unverified for current version).
- **feed** — sitemap/schema.org JSON-LD on pages (unverified).

## Data

Ingredients with quantities, steps, ratings, tags.

## FoodSavr mapping

Recipes class; ingredients to shopping list.

## Risks and constraints

Content is user-contributed and copyrighted; scraping breaches terms (unverified).

## Existing work

`hhursev/recipe-scrapers` (verify supported sites).

## Sources

- https://github.com/hhursev/recipe-scrapers — scraper library
