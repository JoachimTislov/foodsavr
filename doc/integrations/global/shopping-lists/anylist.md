---
id: global-anylist
name: AnyList
scope: global
category: shopping-lists
operator: Purple Cover, Inc.
access: [api-private, export]
auth: username-password
data: [lists, recipes]
item_level: true
cost: freemium
user_base: millions of users, mainly US (unverified)
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# AnyList

Shared grocery list and recipe/meal-plan app with iOS, Android and web clients. Useful as a two-way list sync target for US users.

## Access

- **api-private** — no public API found; community reverse-engineered clients use the app's endpoints with email/password login (unverified details).
- **export** — recipe and list sharing/export inside the app (unverified).

## Data

Lists with items (name, quantity, category, checked), recipes with ingredients, meal plan calendar. No EAN.

## FoodSavr mapping

Maps to `lists` and `recipes`/`plans`. Quantity is text. Not purchase data.

## Risks and constraints

- Unofficial API may break; credential storage needed.
- Amazon retired the Alexa List API on 2024-07-01, ending AnyList's native Alexa sync: shows dependency risk of third-party list APIs.

## Existing work

- Community clients exist (unverified; search GitHub `anylist api`)

## Sources

- https://help.anylist.com/articles/alexa-skill-update-july-2024/ — Alexa list API shutdown notice
- https://www.anylist.com — product
