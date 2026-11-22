---
id: no-just-eat-no
name: Just Eat Norway
scope: no
category: food-delivery
operator: Just Eat Takeaway.com
access: [bot, export]
auth: unknown
data: [orders, line-items]
item_level: false
cost: free
user_base: unknown, status unverified
tos_risk: medium
fit: 1
status: researched
last_verified: 2026-11-21
---

# Just Eat Norway

Norwegian arm founded 2005. Current activity in 2026 is unverified; Just Eat Takeaway announced ending Denmark operations on 30 April 2026.

## Access

- No API or community client found. GDPR export presumed (unverified).

## Data

Order history with restaurant, dish names, quantities, price and timestamp. Dish-level (restaurant meals), not groceries; no EAN.

## FoodSavr mapping

Orders -> meal log / consumption events (what was eaten out); grocery orders via the same platform (quick-commerce) would map to `LineItem` purchases. Low relevance for inventory.

## Risks and constraints

- Consumer APIs undocumented; token handling and bot protection.
- GDPR access request is the sanctioned path but is manual.

## Existing work

- None found.

## Sources

- [JET exits Denmark](https://newsroom.justeattakeaway.com/en-WW/262776-just-eat-takeaway-com-intends-to-cease-operations-in-denmark/)
- [Konkurransetilsynet](https://konkurransetilsynet.no/better-competition-in-the-food-ordering-platforms-market/?lang=en) — Norway market context.
