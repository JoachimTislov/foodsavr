---
id: global-paprika
name: Paprika Recipe Manager
scope: global
category: recipes
operator: Hindsight Labs
access: [export, api-private]
auth: username-password
data: [recipes, plans, lists]
item_level: true
cost: paid
user_base: Popular paid recipe app (iOS/Android/desktop); sync via paprikaapp.com account
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Paprika Recipe Manager

Paprika is a paid recipe manager with meal planner, pantry and grocery lists. No official public API; sync uses a cloud account.

## Access

- **export** - app exports recipes (.paprikarecipes archive, HTML) and backups.
- **api-private** - reverse-engineered sync API at `paprikaapp.com/api/v2/sync/` (recipes, groceries, meals, pantry) used by community clients (unverified current state).

## Data

Recipes with ingredients text, directions, categories, photos; meal plan entries; pantry; grocery lists.

## FoodSavr mapping

Recipe import via export file (low risk); live sync via private API (higher risk).

## Risks and constraints

- No official API; ToS risk for private API; auth is account password.

## Existing work

- Community Python/JS clients on GitHub (unverified names).

## Sources

- https://www.paprikaapp.com/ - product site
- https://www.paprikaapp.com/help/ - help (export/import)
