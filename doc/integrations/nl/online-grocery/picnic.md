---
id: nl-picnic
name: Picnic
scope: nl
category: online-grocery
operator: Picnic Technologies
access: [api-private]
auth: username-password
data: [orders, products, prices]
item_level: true
cost: free
user_base: App-only grocer in NL, DE, FR
tos_risk: medium
fit: 5
status: researched
last_verified: 2026-11-21
---

# Picnic

App-only online supermarket. Python and Node clients use the mobile endpoints for search, cart and deliveries (including order history).

## Access

- **api-private** — `python-picnic-api2` (successor of `MikeBrink/python-picnic-api`), `MRVDH/picnic-api` (Node/TypeScript), C# and Perl clients; set country code NL/DE/FR.

## Data

Deliveries with items, quantities, prices; search with product details.

## FoodSavr mapping

Deliveries to purchases/`LineItem`; app-only so complete history.

## Risks and constraints

Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR. The Python library notes rapid API changes.

## Existing work

`codesalatdev/python-picnic-api` (python-picnic-api2), `MRVDH/picnic-api`, Picnic.Api (NuGet), WWW::Picnic.

## Sources

- https://pypi.org/project/python-picnic-api2/ — Python client
- https://github.com/MRVDH/picnic-api/ — Node client
- https://sources.debian.org/src/python-picnic-api2/1.3.1-2/README.md — README
- https://nuget.org/packages/Picnic.Api — C# client
