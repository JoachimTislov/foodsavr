---
id: eu-just-eat-takeaway
name: Just Eat Takeaway.com
scope: eu
category: food-delivery
operator: Just Eat Takeaway.com (Prosus, 2025, unverified)
access: [api-partner, export, bot]
auth: oauth2
data: [orders]
item_level: true
cost: partner
user_base: Tens of millions of users in UK, NL, DE, BE, AT, PL, IE and others
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Just Eat Takeaway.com

Brands Just Eat (UK, IE), Thuisbezorgd (NL), Lieferando (DE, AT), Takeaway.com (BE and others). Developer site covers JET Connect (POS integration) and JET Go (delivery); these are partner APIs.

## Access

- **api-partner** — developers.just-eat.com (restaurant/POS integration).
- **export** — GDPR request or account order history pages.
- **bot** — scraping order history.

## Data

Partner APIs expose restaurant-side orders. Consumer order history lists restaurant, items, totals (unverified).

## FoodSavr mapping

Meal logging only; Just Eat also lists grocery partners (low volume).

## Risks and constraints

No consumer API. Partner terms bind to restaurants. Covers sub-brands thuisbezorgd (nl) and lieferando (de) in separate entries.

## Existing work

Community wrappers exist (e.g. @datafire/just_eat) and are stale (unverified).

## Sources

- https://apis.io/providers/just-eat/ — API catalogue
- https://apitracker.io/a/just-eat/developers — developer overview
- https://business.just-eat.co.uk/on-demand-delivery — JET Go
