---
id: no-meny-nettbutikk
name: Meny online ordering (NorgesGruppen)
scope: no
category: online-grocery
operator: NorgesGruppen ASA / Meny stores
access: [bot, export]
auth: unknown
data: [orders, line-items, products, prices]
item_level: true
cost: unknown
user_base: Norway nationwide chain customers; online share unknown
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Meny online ordering (NorgesGruppen)

Meny stores offer online ordering with pickup/delivery. No developer access found; item-level data only via the user's account.

## Access

- **bot** — no public or reverse-engineered API for the online shop found in searches. Browser automation on the user's logged-in session would be the only route (unverified feasibility).
- **export** — GDPR data request or order e-mail/receipt forward (unverified whether item-level).

## Data

Order confirmations and past orders contain products and prices (assumed; unverified). No EAN confirmed.

## FoodSavr mapping

Orders -> purchases; map product names to `LineItem`. Prefer the chain's loyalty/receipt integration (see grocery-retail entries by other agents) where it exists.

## Risks and constraints

- No documented API; scraping may breach ToS.
- Little to no community tooling found.
- Availability of online shop per store varies.

## Existing work

- None found for Norway. [hydra-engineers/grocery-stores](https://github.com/hydra-engineers/grocery-stores) and Apify MENY scrapers cover Meny Denmark only.

## Sources

- [Search: Meny/Kiwi/Coop unofficial API (GitHub, Apify)](https://github.com/hydra-engineers/grocery-stores) — no Norwegian online-shop client found.
- [Helge Sverre gist: reverse-engineered Rema 1000/Coop/Trumf APIs](https://gist.github.com/HelgeSverre/80a7f34f874336324184a0c513c2e6a2) — covers Coop member app, not online shop ordering.
