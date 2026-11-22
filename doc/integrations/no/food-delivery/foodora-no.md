---
id: no-foodora-no
name: foodora Norway
scope: no
category: food-delivery
operator: Foodora Norway AS (Delivery Hero)
access: [api-private, export, bot]
auth: username-password
data: [orders, line-items]
item_level: false
cost: free
user_base: Norway consumers
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# foodora Norway

Largest-or-second food delivery platform in Norway, also quick-commerce groceries (e.g. SPAR Norway delivered with Foodora).

## Access

- **api-private** — consumer app API; `steipete/ordercli` implements login (email/password, MFA, Chrome session import) and `history` with per-order detail. Bundled presets list HU, AT, CZ, SE; Norway support is (unverified) via `foodora countries`.
- **export** — GDPR access request (privacy policy lists order IDs, history, product names and quantities).
- No official consumer API; Delivery Hero partner APIs target restaurants (not consumers).

## Data

Order history with restaurant, dish names, quantities, price and timestamp. Dish-level (restaurant meals), not groceries; no EAN.

## FoodSavr mapping

Orders -> meal log / consumption events (what was eaten out); grocery orders via the same platform (quick-commerce) would map to `LineItem` purchases. Low relevance for inventory.

## Risks and constraints

- Consumer APIs undocumented; token handling and bot protection.
- GDPR access request is the sanctioned path but is manual.

## Existing work

- [steipete/ordercli](https://github.com/steipete/ordercli/) — foodora CLI.

## Sources

- [steipete/ordercli](https://github.com/steipete/ordercli/) — CLI with foodora history.
- [foodora Norway privacy policy](https://www.foodora.no/en/contents/privacy.htm) — order data held.
- [Konkurransetilsynet](https://konkurransetilsynet.no/better-competition-in-the-food-ordering-platforms-market/?lang=en) — market context.
- [Retail Insight: SPAR Norway quick-commerce with Foodora](https://www.retail-insight-network.com/newsletters/spar-norway-quickcommerce-grocery-delivery)
