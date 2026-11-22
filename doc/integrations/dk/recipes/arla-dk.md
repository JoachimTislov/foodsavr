---
id: dk-arla-dk
name: Arla Danmark recipes
scope: dk
category: recipes
operator: Arla Foods amba
access: [bot]
auth: none
data: [recipes]
item_level: true
cost: free
user_base: Large Danish recipe site run by the dairy cooperative (size unverified)
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Arla Danmark recipes

Recipe collection on arla.dk. No public API found. A commercial extractor (Thunderbit) scrapes Arla recipe pages, which shows the pages are machine-readable ([template](https://thunderbit.com/template/arla-recipe-scraper)). JSON-LD presence not verified.

## Access

- **bot** — Page parsing, per-URL import. Generic parsers: [recipe-scrapers](https://pypi.org/p/recipe-scrapers) (Arla.dk support unverified).
- No official API or MCP server found.

## Data

Title, ingredients, steps, portions, images (if structured data present).

## FoodSavr mapping

Recipe import by URL to meal plans and shopping lists; Danish ingredient strings need parsing.

## Risks and constraints

Recipe content copyright; check Arla terms before bulk use; per-user import is the safer pattern.

## Existing work

Thunderbit template; generic scrapers.

## Sources

- https://thunderbit.com/template/arla-recipe-scraper
- https://pypi.org/p/recipe-scrapers
