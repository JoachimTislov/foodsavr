---
id: no-pizzabakeren
name: Pizzabakeren
scope: no
category: food-delivery
operator: Pizzabakeren AS (unverified)
access: [bot, export]
auth: username-password
data: [orders, line-items]
item_level: false
cost: free
user_base: Norway consumers
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Pizzabakeren

Norwegian pizza chain with own ordering app/site; nothing on API access found.

## Access

- No public or community API found for the Norwegian service. App/web accounts typically show order history (unverified).
- Orders also appear in aggregator apps (Wolt/foodora) if placed there.

## Data

Order history with restaurant, dish names, quantities, price and timestamp. Dish-level (restaurant meals), not groceries; no EAN.

## FoodSavr mapping

Orders -> meal log / consumption events (what was eaten out); grocery orders via the same platform (quick-commerce) would map to `LineItem` purchases. Low relevance for inventory.

## Risks and constraints

- Consumer APIs undocumented; token handling and bot protection.
- GDPR access request is the sanctioned path but is manual.

## Existing work

- None found for Norway.

## Sources

- No Pizzabakeren API found in web search 2026-11-21 (unverified).
