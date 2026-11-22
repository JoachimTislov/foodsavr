---
id: eu-uber-eats
name: Uber Eats
scope: eu
category: food-delivery
operator: Uber Technologies
access: [export, api-partner, bot]
auth: oauth2
data: [orders]
item_level: true
cost: free
user_base: Hundreds of millions of users globally; large in UK, FR, ES, DE, NL, PL
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Uber Eats

Restaurant and grocery delivery marketplace. Consumers can export their order history; the documented APIs are for merchants and partners, not for reading a consumer's own orders.

## Access

- **export** — Uber account 'Download your data' (privacy portal) includes Eats order history (unverified detail).
- **api-partner** — Uber Eats Marketplace APIs (orders, menus, store activation) for restaurants/POS partners; OAuth2 client-credentials via developer.uber.com. Consumer Delivery APIs need written approval.
- **bot** — browser automation of order history pages.

## Data

Merchant APIs expose orders for the merchant's own stores (items, quantities, prices). Consumer export: order list with restaurant, date, items and total (unverified).

## FoodSavr mapping

Orders are restaurant meals: mainly useful for meal logging (consumed outside home), little for inventory. Grocery orders via Uber Eats (partner stores) may give line items.

## Risks and constraints

Partner APIs are not available to a consumer app. Scraping breaches terms. Export is manual.

## Existing work

No consumer-order clients verified.

## Sources

- https://developer.uber.com/docs/consumer-delivery/introduction — Uber delivery APIs, approval required
- https://providers.apievangelist.com/providers/uber-eats/ — API overview (third party)
