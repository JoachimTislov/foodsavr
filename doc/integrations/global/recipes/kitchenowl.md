---
id: global-kitchenowl
name: KitchenOwl
scope: global
category: recipes
operator: KitchenOwl community (self-hosted)
access: [api-public]
auth: oauth2
data: [lists, recipes, plans]
item_level: true
cost: free
user_base: Small self-hosted, Flutter-based app
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# KitchenOwl

Self-hosted Flutter app for shopping lists, recipes, meal planner and expense splitting. Open-source Flask backend with REST API.

## Access

- **api-public** - REST API of the backend (`/api/household/{id}/shoppinglist`, `/recipe`, `/planner`), JWT auth via username/password login; OpenAPI details unverified.

## Data

Shopping list items, recipes with ingredients, planner entries, categories.

## FoodSavr mapping

Shared list sync and recipe import; no expiry/stock.

## Risks and constraints

- API stability not guaranteed; self-hosted URL entry.

## Existing work

- Official apps are Flutter (same stack as FoodSavr).

## Sources

- https://kitchenowl.org/ - project site
- https://github.com/TomBursch/kitchenowl - source
