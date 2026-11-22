---
id: se-ica-recept
name: ICA Recept
scope: se
category: recipes
operator: ICA Gruppen AB
access: [api-private, bot, mcp]
auth: oidc
data: [recipes, lists]
item_level: true
cost: free
user_base: Large Swedish recipe site and app section (size unverified)
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# ICA Recept

Recipe collection on ica.se and in the ICA app. No official recipe API.

## Access

- **bot** — ica.se is in the `recipe-scrapers` Python library's supported list (per PyPI listing); hosted Apify actor `mrdoe/ica-scraper` (ingredients, steps, time, ratings; pay-per-result).
- **api-private / mcp** — `kanylbullen/ica-mcp` lists saved and random recipes and fetches one recipe's ingredients and steps; its recipe search endpoints return errors.
- **dataset** — Hugging Face `amcoff/recept` has scraped ICA recipe metadata.

## Data

Title, ingredients, steps, time, difficulty, ratings.

## FoodSavr mapping

Recipes input class; ingredients to shopping list and inventory matching. Saved recipes via the authenticated app API if the user connects ICA.

## Risks and constraints

Scraping against terms (unverified); copyright on recipe text and images.

## Existing work

- https://github.com/hhursev/recipe-scrapers
- https://github.com/kanylbullen/ica-mcp
- https://apify.com/mrdoe/ica-scraper

## Sources

- https://pypi.org/project/recipe-scrapers/15.2.1/ — ica.se supported
- https://apify.com/mrdoe/ica-scraper.md — recipe scraper
- https://github.com/kanylbullen/ica-mcp — recipe tools and limits
