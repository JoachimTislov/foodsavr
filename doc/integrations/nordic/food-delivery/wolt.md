---
id: nordic-wolt
name: Wolt
scope: nordic
category: food-delivery
operator: Wolt Enterprises Oy (DoorDash)
access: [api-private, export, api-partner]
auth: unknown
data: [orders, line-items]
item_level: true
cost: partner
user_base: Large user base across FI, DK, NO, SE and other countries; also delivers groceries
tos_risk: high
fit: 3
status: researched
last_verified: 2026-11-21
---

# Wolt

Delivery platform for restaurants and groceries (Wolt Market, partner supermarkets). Useful to FoodSavr for grocery order history; restaurant orders are not inventory. See also `no/food-delivery/wolt-no.md`.

## Access

- **api-private** — Community clients use the undocumented consumer API: [woltapi](https://pypi.org/project/woltapi/) (Python; order history, saved addresses), [wolt-cli](https://mekedron.github.io/wolt-cli/) (Go; read-only order history, SQLite sync), [DataWolt](https://github.com/idoavrah/datawolt) (Chrome extension reads the order history page), plus a [gist of consumer endpoints](https://gist.github.com/OzTamir/7ed2b49b8628d88c086d65b0d1730c36). Maintenance status unchecked.
- **api-partner** — Official APIs (Order, Venue, Retail, Drive) are merchant/partner side and expose no customer history ([developer.wolt.com](https://developer.wolt.com/docs/api)).
- **export** — GDPR data request (content and format unverified).

## Data

Order history: venue, date, items with names and quantities, prices (per woltapi docs; EAN not expected, unverified).

## FoodSavr mapping

Grocery orders -> purchases with `LineItem` (name, qty, price). Restaurant orders ignored. No EAN or expiry.

## Risks and constraints

Needs the user's session/credentials (possible 2FA); private API can change; terms breach and account-ban risk.

## Existing work

woltapi, wolt-cli, DataWolt (above). No MCP server found.

## Sources

- https://pypi.org/project/woltapi/
- https://mekedron.github.io/wolt-cli/
- https://github.com/idoavrah/datawolt
- https://gist.github.com/OzTamir/7ed2b49b8628d88c086d65b0d1730c36
- https://developer.wolt.com/docs/api
