---
id: no-adams-matkasse
name: Adams Matkasse
scope: no
category: meal-kits
operator: LMK Group (Adams Matkasse)
access: [export, bot]
auth: username-password
data: [orders, recipes, plans]
item_level: false
cost: unknown
user_base: Norwegian households with subscription; size unknown
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# Adams Matkasse

Norwegian meal-kit subscription, part of LMK Group with Godtlevert.

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
- Same group as Godtlevert; shared backend is possible (unverified).

## Existing work

- None found for Norway.

## Sources

- [Nordic9 company profile](https://nordic9.com/companies/adams-matkasse-company9096199259/) — group ownership.
- [App Store rank page](https://mwm.ai/apps/adams-matkasse/946946965) — app exists, no API mention.
- No Adams Matkasse API found in web search 2026-11-21.
