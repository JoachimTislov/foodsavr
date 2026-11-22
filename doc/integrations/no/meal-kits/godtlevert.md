---
id: no-godtlevert
name: Godtlevert
scope: no
category: meal-kits
operator: Cheffelo Norway AS (LMK Group)
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

# Godtlevert

Norwegian meal-kit subscription. Controller listed as Cheffelo Norway AS, org.nr 899 306 562.

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
- Sister brand of Adams Matkasse.

## Existing work

- None found for Norway.

## Sources

- [europeanpurpose.com Godtlevert](https://europeanpurpose.com/tool/godtlevert) — company details.
- [Nordic9 profile](https://nordic9.com/companies/adams-matkasse-company9096199259/) — group.
