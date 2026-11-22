---
id: se-linas-matkasse
name: Linas Matkasse
scope: se
category: meal-kits
operator: Carolinas Matkasse AB
access: [bot, export]
auth: unknown
data: [orders, recipes]
item_level: false
cost: unknown
user_base: Swedish meal-kit subscription (size unknown)
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Linas Matkasse

Swedish recipe box subscription with an app (80+ weekly recipes per the App Store listing). No public API, developer portal or unofficial client found.

## Access

- **bot** — recipes on the public website; schema.org/Recipe markup not checked (unverified).
- **export** — weekly menu/recipe emails, user-forwarded (unverified).
- An API Evangelist profile exists but states no public developer portal or SDK is published.

## Data

Weekly recipes with ingredients (from the app description); delivery/order data only in the account.

## FoodSavr mapping

Recipes and plan input; ingredients of delivered boxes would be inventory, but no machine-readable order feed was found.

## Risks and constraints

No documented access; scraping terms unchecked.

## Existing work

None found for Linas specifically.

## Sources

- https://apps.apple.com/app/id432892817 — app listing, 80+ recipes weekly
- https://providers.apievangelist.com/providers/linas-matkasse/ — no public API per third-party profile
