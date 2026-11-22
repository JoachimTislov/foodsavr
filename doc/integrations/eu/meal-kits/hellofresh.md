---
id: eu-hellofresh
name: HelloFresh
scope: eu
category: meal-kits
operator: HelloFresh SE
access: [mcp, api-private, bot]
auth: username-password
data: [orders, recipes, plans]
item_level: true
cost: paid
user_base: Largest meal-kit company; US, DE, UK, NL, BE, FR, others
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# HelloFresh

Pan-EU parent of HelloFresh country sites (also Green Chef, EveryPlate, Factor). Weekly menus, recipes with ingredients and nutrition, and the user's box selections and delivery schedule.

## Access

- **mcp** — community servers: `chrischall/hellofresh-mcp` (deliveries, menus, meal picks; 26 tools), `@striderlabs/mcp-hellofresh` (Playwright, login with user credentials), `markswendsen-code/mcp-hellofresh` (weekly recipes).
- **api-private** — web/app endpoints used by the scrapers below.
- **bot** — Playwright login flows as above.

## Data

Menus, recipes (ingredients, allergens, tags, nutrition), upcoming and past boxes. Databases cover 17 countries.

## FoodSavr mapping

Selected box meals map to plans and recipes; ingredient lists give expected pantry additions on delivery day. Quantities are given per portion.

## Risks and constraints

No official public API found. MCP servers ask for the user's HelloFresh credentials; review code first. Scraping breaks terms (unverified).

## Existing work

`Muetze42/hellofresh-database` (PHP, 17 countries), `dcragusa/HelloFreshRecipes`, `ashkarin/go-hellofresh`, HelloScrape, Apify HelloFresh scraper (BE).

## Sources

- https://claudemarketplaces.com/mcp/chrischall/hellofresh-mcp — MCP server
- https://glama.ai/mcp/servers/markswendsen-code/mcp-hellofresh — MCP server
- https://www.pkgstats.com/pkg:@striderlabs/mcp-hellofresh — MCP package
- https://awesome.ecosyste.ms/projects/github.com%2FMuetze42%2Fhellofresh-database — recipe database
- https://apitracker.io/a/hellofresh/integrations — no official API listed
