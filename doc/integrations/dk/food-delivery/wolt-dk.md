---
id: dk-wolt-dk
name: Wolt Denmark
scope: dk
category: food-delivery
operator: Wolt Enterprises Oy (DoorDash)
access: [api-private, export]
auth: unknown
data: [orders, line-items]
item_level: true
cost: free
user_base: Large in Danish cities; also delivers groceries from partner stores (size unverified)
tos_risk: high
fit: 3
status: researched
last_verified: 2026-11-21
---

# Wolt Denmark

Same service and access as `nordic/food-delivery/wolt.md`; this entry only records the Denmark specifics. Grocery orders (Wolt Market and partner shops) are useful; restaurant orders are not inventory.

## Access

- **api-private** — Community consumer-API clients (woltapi, wolt-cli, DataWolt) are described in the nordic entry. Danish use not separately verified.
- **export** — GDPR data request; Wolt publishes a subject-access page for couriers; the customer route and format were not verified ([Wolt DK SAR](https://explore.wolt.com/en/dnk/couriers/learning-center/your-subject-access-request), courier-oriented).
- Official APIs (Order, Venue, Retail, Drive) are partner-side only ([developer.wolt.com](https://developer.wolt.com/docs/api)).

## Data

Order history with venue, items, prices; Apify scrapers list Wolt Market catalogues with EAN ([actor](https://apify.com/studio-amba/wolt-scraper.md)).

## FoodSavr mapping

Grocery orders to purchases; catalogue EAN could enrich matching.

## Risks and constraints

Private API and ToS risk as in the nordic entry.

## Existing work

See `nordic/food-delivery/wolt.md`.

## Sources

- https://developer.wolt.com/docs/api
- https://apify.com/studio-amba/wolt-scraper.md
- https://explore.wolt.com/en/dnk/couriers/learning-center/your-subject-access-request
