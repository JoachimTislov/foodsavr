---
id: se-hellofresh
name: HelloFresh Sweden
scope: se
category: meal-kits
operator: HelloFresh Sverige AB (HelloFresh SE group)
access: [api-private, bot]
auth: username-password
data: [orders, recipes, plans]
item_level: false
cost: free
user_base: Large Nordic meal-kit subscription (Swedish size unknown)
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# HelloFresh Sweden

Meal-kit subscription at hellofresh.se. HelloFresh runs one platform across countries; a community CLI documents its customer API with a configurable country (default France).

## Access

- **api-private** — `AurelienLoyer/hellofresh-api-cli` (Node): logs in with email+password, caches tokens locally, exposes subscription, deliveries and weekly menu with recipe images; `BASE_URL`/`COUNTRY`/`LOCALE` are configurable. Swedish market not tested per README.
- No official developer API found.

## Data

Subscription, deliveries, weekly menu with recipes. Ingredient lists per recipe likely available (unverified).

## FoodSavr mapping

Recipes and meal plan; delivered recipe ingredients could prefill inventory. Overlaps with HelloFresh entries in other scopes (`eu` or `global`).

## Risks and constraints

Private API; credentials stored; terms unverified.

## Existing work

- https://github.com/AurelienLoyer/hellofresh-api-cli
- https://github.com/arronhunt/hellofresh-module (old Node module)

## Sources

- https://github.com/AurelienLoyer/hellofresh-api-cli — features, configurable country
