---
id: se-wolt
name: Wolt Sweden
scope: se
category: food-delivery
operator: Wolt Enterprises (DoorDash)
access: [api-partner, api-private, export]
auth: unknown
data: [orders, products, prices]
item_level: true
cost: partner
user_base: Large Nordic delivery platform incl. grocery venues in Sweden
tos_risk: high
fit: 3
status: researched
last_verified: 2026-11-21
---

# Wolt Sweden

Restaurant and retail delivery; Swedish grocery stores (for example Coop) list venues on Wolt. Orders from grocery venues would be item-level. Wolt is cross-country; this entry covers the Swedish context only.

## Access

- **api-partner** — official Wolt developer docs cover the Wolt Drive API (merchants using Wolt as last-mile carrier; Bearer token, credentials from the local Wolt Drive team) and partner integrations. Not a consumer data API. A Swedish Drive signup page exists.
- **api-private** — `ilyafeldman/pywolt` wraps Wolt's internal web API (venue/menu browsing); consumer order history not confirmed.
- **export** — GDPR data request (unverified detail).

## Data

Venue menus/items and prices via the internal API; Drive API handles delivery orders created by merchants.

## FoodSavr mapping

Order history for grocery venues, if accessible, as purchases; otherwise no use.

## Risks and constraints

Official APIs serve merchants, not consumers. Private API use is unauthorised.

## Existing work

- https://github.com/ilyafeldman/pywolt
- https://github.com/ikurcubic/wolt-api (Items/Inventory API library for merchants)

## Sources

- https://developer.wolt.com/docs/wolt-drive — Drive API overview
- https://developer.wolt.com/docs/partner-integrations — partner integration basics
- https://explore.wolt.com/en/swe/wolt-drive/api-integration/signup — Swedish Drive signup
- https://github.com/ilyafeldman/pywolt — internal web API wrapper
