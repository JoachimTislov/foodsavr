---
id: gb-gousto
name: Gousto
scope: gb
category: meal-kits
operator: Gousto Ltd
access: [api-private, bot, export]
auth: unknown
data: [recipes, orders, plans]
item_level: true
cost: free
user_base: UK #1 or #2 recipe box (~hundreds of thousands of subscribers, unverified)
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# Gousto

UK recipe-box service. Public recipe pages are backed by an undocumented CMS read endpoint; the user's orders and menu selections need the account.

## Access

- **api-private** — `production-api.gousto.co.uk/cmsreadbroker/v1/recipes` (listing, offset paging) and `/recipe/{slug}` (full ingredients and steps), undocumented and used by `recipe-scrapers` tests.
- **export** — GDPR request for order history (unverified).
- **bot** — account scraping.

## Data

Recipe: title, ingredients with quantities, steps, nutrition, ratings. Catalogue of several thousand recipes.

## FoodSavr mapping

Recipes and box contents map to recipes/plans; delivered ingredient quantities map to inventory additions on delivery.

## Risks and constraints

Undocumented endpoints; ToS unverified. Recipe content is copyrighted.

## Existing work

`hhursev/recipe-scrapers` Gousto scraper, `sdjmchattie/recipe-converter` (Gousto to Paprika), community 'Gousto Recipes' skill.

## Sources

- https://github.com/sdjmchattie/recipe-converter — Gousto to Paprika converter
- https://clawhub.ai/gousto — community recipes skill
- https://github-redirect.dependabot.com/hhursev/recipe-scrapers/issues/376 — recipe-scrapers issue
