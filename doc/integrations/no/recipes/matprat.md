---
id: no-matprat
name: Matprat
scope: no
category: recipes
operator: Opplysningskontoret for egg og kjøtt (unverified)
access: [bot, feed]
auth: none
data: [recipes, nutrition]
item_level: true
cost: free
user_base: Large Norwegian audience (unverified)
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# Matprat

Norwegian recipe site with large recipe catalogue; listed as supported by recipe-scrapers.

## Access

- **bot/feed** — no official developer API found. Recipe pages publish schema.org `Recipe` data, parsed by the open-source `recipe-scrapers` library for supported sites (per its docs). Scraping is the only access.
- No MCP server found.

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

- [parse.bot matprat.no API](https://parse.bot/marketplace/daf30cd7-8a16-4f2c-89bd-2cefb025915c/matprat-no-api) — paid third-party wrapper; states no official API.
- [kaiba-scraper](https://awesome.ecosyste.ms/projects/github.com%2Fthomasborgen%2Fkaiba-scraper) — PoC scraper.
- [recipe-scrapers on PyPI](https://pypi.org/project/recipe-scrapers/) — supported sites list.
