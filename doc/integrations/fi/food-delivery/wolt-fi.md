---
id: fi-wolt-fi
name: Wolt Finland
scope: fi
category: food-delivery
operator: Wolt Enterprises Oy (DoorDash)
access: [api-private, export]
auth: unknown
data: [orders, line-items]
item_level: true
cost: free
user_base: Wolt's home market; restaurants and groceries (K-Market, K-Supermarket and others on Wolt Market per Apify listing)
tos_risk: high
fit: 3
status: researched
last_verified: 2026-11-21
---

# Wolt Finland

Wolt's home market. Same access story as `nordic/food-delivery/wolt.md`; this entry records the Finnish grocery angle.

## Access

- **api-private** — Community consumer-API clients (woltapi, wolt-cli, DataWolt); see the nordic entry.
- **export** — GDPR data request; customer format unverified.
- Official Order/Retail/Drive APIs are partner-side only ([developer.wolt.com](https://developer.wolt.com/docs/api)). Third-party listings say the public wolt.com API exposes no order history ([parse.bot](https://parse.bot/marketplace/a7730aee-2b8c-4600-872f-3b9854bc3607/wolt-com-api)).

## Data

Grocery catalogue with EAN and unit prices from partner supermarkets ([Apify](https://apify.com/studio-amba/wolt-scraper.md)); personal order history only via private API/export.

## FoodSavr mapping

Grocery orders to purchases; catalogue EAN for matching.

## Risks and constraints

ToS and account-ban risk with private API.

## Existing work

See the nordic entry.

## Sources

- https://developer.wolt.com/docs/api
- https://apify.com/studio-amba/wolt-scraper.md
- https://parse.bot/marketplace/a7730aee-2b8c-4600-872f-3b9854bc3607/wolt-com-api
