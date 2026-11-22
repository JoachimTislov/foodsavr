---
id: no-wolt-no
name: Wolt Norway
scope: no
category: food-delivery
operator: Wolt Enterprises (DoorDash)
access: [api-private, export, bot]
auth: session-cookie
data: [orders, line-items]
item_level: false
cost: free
user_base: Norway consumers
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Wolt Norway

Food and grocery delivery operating in 50+ Norwegian locations. Wolt also lists McDonald's and other chains in Norway.

## Access

- **api-private** — consumer API; community tools use the user's session token from browser dev tools (`drugoi/data-exports` Wolt orders script; `idoavrah/datawolt` Chrome extension pulls 12 months).
- **export** — GDPR subject access request via Wolt.
- Official [Wolt developer API](https://developer.wolt.com/docs/api) is for merchant/partner Order API, not consumers.

## Data

Order history with restaurant, dish names, quantities, price and timestamp. Dish-level (restaurant meals), not groceries; no EAN.

## FoodSavr mapping

Orders -> meal log / consumption events (what was eaten out); grocery orders via the same platform (quick-commerce) would map to `LineItem` purchases. Low relevance for inventory.

## Risks and constraints

- Consumer APIs undocumented; token handling and bot protection.
- GDPR access request is the sanctioned path but is manual.

## Existing work

- [idoavrah/datawolt](https://github.com/idoavrah/datawolt) — Streamlit visualizer, Chrome extension collects history.
- [drugoi/data-exports](https://awesome.ecosyste.ms/projects/github.com%2Fdrugoi%2Fdata-exports) — Wolt orders export script.

## Sources

- [Wolt developer docs](https://developer.wolt.com/docs/api) — merchant Order API.
- [datawolt](https://github.com/idoavrah/datawolt)
- [drugoi/data-exports](https://awesome.ecosyste.ms/projects/github.com%2Fdrugoi%2Fdata-exports)
- [Wolt SAR page](https://explore.wolt.com/en/dnk/couriers/learning-center/your-subject-access-request) — access-request process (courier page, consumer process (unverified)).
- [Wolt Norway](https://wolt.com/en/nor/oslo) — coverage.
