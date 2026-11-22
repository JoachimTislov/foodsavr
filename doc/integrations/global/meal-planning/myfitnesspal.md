---
id: global-myfitnesspal
name: MyFitnessPal
scope: global
category: meal-planning
operator: MyFitnessPal (Francisco Partners)
access: [api-partner, export]
auth: oauth2
data: [nutrition, plans]
item_level: true
cost: partner
user_base: Very large global user base (100M+ claimed)
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# MyFitnessPal

Calorie and food diary app. The public API is partner-only (application required); users can export diary data as CSV (premium).

## Access

- **api-partner** - MyFitnessPal API via application at the developer portal; access reportedly restricted/closed to new apps (unverified).
- **export** - Premium users can export nutrition data as CSV.

## Data

Diary entries with food name, meal, calories and macros; weight; no barcodes in export (unverified).

## FoodSavr mapping

Consumption data to infer usage; low coupling to inventory.

## Risks and constraints

- Partner gating; unofficial scrapers breach ToS.

## Existing work

- Unofficial python-myfitnesspal library (unverified maintenance).

## Sources

- https://www.myfitnesspal.com/api - API page
- https://support.myfitnesspal.com/hc/en-us/articles/360032273352-Data-Export - export help (unverified path)
