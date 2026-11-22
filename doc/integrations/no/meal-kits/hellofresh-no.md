---
id: no-hellofresh-no
name: HelloFresh Norway
scope: no
category: meal-kits
operator: HelloFresh Norway AS (org.nr 925 472 972)
access: [export, bot]
auth: username-password
data: [orders, recipes, plans]
item_level: false
cost: unknown
user_base: Norwegian households with subscription; size unknown
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# HelloFresh Norway

HelloFresh's Norwegian meal-kit business (registered in Moss).

## Access

- **export** — GDPR subject-access request or order e-mails; recipe cards are on the website/app (unverified format).
- **bot** — browser automation on the logged-in account for weekly menus and recipes (unverified).
- No public API, GitHub client or MCP server found.

## Data

Weekly box contents with recipes and ingredient lists; ingredient quantities per recipe (assumed; unverified). No EAN.

## FoodSavr mapping

Recipes -> FoodSavr recipes/meal plan; delivered ingredients -> inventory with short expiry; delivery date known from the subscription.

## Risks and constraints

- Private account data; automation may breach ToS.
- Global HelloFresh recipe site exposes schema.org recipes; a commercial scraping API exists (Actowiz) but is not official.

## Existing work

- None found for Norway.

## Sources

- [Brønnøysund register](https://virksomhet.brreg.no/en/oppslag/enheter/925472972) — entity.
- [Actowiz HelloFresh scraping API](https://www.actowizsolutions.com/hellofresh-web-scraping-api.php) — third-party commercial scraper.
- [APITracker HelloFresh](https://apitracker.io/a/hellofresh/integrations) — no documented endpoints.
