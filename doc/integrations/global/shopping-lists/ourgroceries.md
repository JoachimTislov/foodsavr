---
id: global-ourgroceries
name: OurGroceries
scope: global
category: shopping-lists
operator: Headsup Software
access: [api-private]
auth: username-password
data: [lists]
item_level: true
cost: freemium
user_base: millions of downloads, US-centric (unverified)
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# OurGroceries

Simple shared grocery list app. No public API found; community clients exist.

## Access

- **api-private** — reverse-engineered API with email/password (unverified; search GitHub `ourgroceries api`).

## Data

Lists, items with name, category, optional note; no EAN.

## FoodSavr mapping

`lists` only, via free-text names.

## Risks and constraints

- Unofficial; may break; credentials needed.
- ToS not reviewed (unverified).

## Existing work

- Python `ourgroceries` package on PyPI (unverified)

## Sources

- https://www.ourgroceries.com — product
- https://pypi.org/project/ourgroceries/ — Python client (unverified)
