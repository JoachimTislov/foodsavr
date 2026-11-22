---
id: no-dominos-no
name: Domino's Norway
scope: no
category: food-delivery
operator: Domino's Pizza Norge
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

# Domino's Norway

Own app/site; per the Domino's NO FAQ, History lists past orders with downloadable receipts.

## Access

- No public or community API found for the Norwegian service. App/web accounts typically show order history (unverified).
- Receipt download is a manual export path.

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

- [Domino's NO FAQ](https://www.dominos.no/en/side/faq) — History and receipts.
- [API Evangelist Domino's](https://providers.apievangelist.com/providers/dominos-pizza/) — no official public API; US unofficial wrappers (npm `dominos`, `pizzapi`) not confirmed for NO.
