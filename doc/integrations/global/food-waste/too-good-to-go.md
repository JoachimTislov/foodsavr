---
id: global-too-good-to-go
name: Too Good To Go
scope: global
category: food-waste
operator: Too Good To Go ApS
access: [api-private, bot]
auth: oauth2
data: [offers, orders]
item_level: false
cost: free
user_base: 100M+ registered users; Europe and North America
tos_risk: high
fit: 3
status: researched
last_verified: 2026-11-21
---

# Too Good To Go

Surplus-food 'Magic Bag' marketplace. No public API; community clients use the mobile app's private API (email login code flow) for store listings, favourites and orders.

## Access

- **api-private** - app API via unofficial clients: `tgtg` (Python, ahivert/tgtg-python), tgtg-client (TypeScript), Dart `tgtg_client`; login via email, tokens saved.
- **bot** - none official.

## Data

Stores, items available, price, pickup window, orders; no ingredient-level contents.

## FoodSavr mapping

Orders/offers; a bag is not itemised, so only as 'surplus meal acquired' event.

## Risks and constraints

- ToS prohibits automation; clients can be rate-limited or blocked; API changed to captcha/DataDome (reported, unverified).
- Low item-level value.

## Existing work

- Clients listed above.

## Sources

- https://pypi.org/project/tgtg/ - Python client
- https://github.com/bengeois/tgtg-client - TypeScript client
- https://pub.dev/documentation/tgtg_client/latest/ - Dart client
