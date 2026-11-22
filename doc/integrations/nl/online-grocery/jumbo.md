---
id: nl-jumbo
name: Jumbo
scope: nl
category: online-grocery
operator: Jumbo Groep Holding
access: [api-private, bot, export]
auth: username-password
data: [orders, products, prices]
item_level: true
cost: free
user_base: NL #2 grocer; Jumbo app and Extra's loyalty
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# Jumbo

Dutch grocer with online delivery. Python wrapper views deliveries, time slots and basket via the mobile API.

## Access

- **api-private** — `python-jumbo-api` (orders, slots, basket; last release 2021), `supermarktconnector` (search), npm `jumbo-wrapper`.
- **export** — GDPR request.

## Data

Orders, products, prices.

## FoodSavr mapping

Orders to purchases/`LineItem`.

## Risks and constraints

Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR. Clients are stale (2021–2022).

## Existing work

`peternijssen/python-jumbo-api`, `bartmachielsen/supermarktconnector`.

## Sources

- https://pypi.org/project/python-jumbo-api — Python wrapper
- https://pypi.org/project/supermarktconnector — connector
- https://www.npmjs.com/package/jumbo-wrapper — Node wrapper
