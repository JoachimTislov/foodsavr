---
id: sg-grab
name: Grab (GrabFood / GrabMart)
scope: sg
category: food-delivery
operator: Grab Holdings
access: [api-partner]
auth: oauth2
data: [orders]
item_level: false
cost: partner
user_base: Southeast Asia
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Grab (GrabFood / GrabMart)

Grab's developer platform serves merchants and partners (GrabFood, GrabExpress). Official OpenAPI SDKs exist for GrabFood. No consumer history API.

## Access

- **api-partner** — developer.grab.com; OAuth2 client credentials, scope `food.partner_api`; base `api.grab.com`, partner API `partner-api.grab.com/grabfood`; Go and Java SDKs.

## Data

Merchant orders, menus, store status.

## FoodSavr mapping

Not usable for diner history.

## Risks and constraints

Partner credentials required.

## Existing work

- https://github.com/grab/grabfood-api-sdk-go
- https://github.com/grab/grabfood-api-sdk-java

## Sources

- https://github.com/grab/grabfood-api-sdk-go — official SDK
- https://github.com/grab/grabfood-api-sdk-java — official SDK
- https://providers.apievangelist.com/providers/grab/ — provider profile
