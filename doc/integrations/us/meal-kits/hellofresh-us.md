---
id: us-hellofresh-us
name: HelloFresh (US)
scope: us
category: meal-kits
operator: HelloFresh SE
access: [api-private, export]
auth: unknown
data: [recipes, orders]
item_level: true
cost: free
user_base: Global meal-kit leader, large US base
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# HelloFresh (US)

No official API. Community scrapers fetch public recipe data from HelloFresh sites; subscription order data is account-only.

## Access

- **api-private** — recipe search endpoints used by the website (Apify scraper targets Belgium).
- **export** — account data request (unverified).

## Data

Recipe name, ingredients, nutrition, allergens, tags, prep time per country.

## FoodSavr mapping

Recipes feed; ingredient lines map to shopping lists.

## Risks and constraints

Scraping terms unreviewed.

## Existing work

- https://github.com/dcragusa/HelloFreshRecipes
- https://github.com/Muetze42/hellofresh-database (17 countries)
- https://github.com/jfeil/HelloFresh-Tandoor-Converter
- https://github.com/ashkarin/go-hellofresh

## Sources

- https://github.com/Muetze42/hellofresh-database — multi-country dataset tool
- https://apify.com/studio-amba/hellofresh-scraper — Belgian scraper
- https://apitracker.io/a/hellofresh — no official API
