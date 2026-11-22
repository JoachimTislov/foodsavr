---
id: de-rewe
name: REWE (Lieferservice, Abholservice)
scope: de
category: online-grocery
operator: REWE Group
access: [api-private, bot, export]
auth: oauth2
data: [orders, prices, offers, products, recipes]
item_level: true
cost: free
user_base: Germany #2 grocer; large online/pickup service; payback in stores
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# REWE (Lieferservice, Abholservice)

German grocer with online shop and mobile app (mobile-api.rewe.de). Reverse-engineering projects document market search, products, offers and basket/ordering with mTLS client certificates from the app.

## Access

- **api-private** — mobile API; `rewerse-engineering` documents unauthenticated endpoints for products, discounts, recipes (no account endpoints); `korb` builds baskets for pickup using mTLS certificates extracted from the app.
- **export** — GDPR request / digital receipt in the REWE app (unverified).
- **bot** — web scraping.

## Data

Products, prices, offers, recipes publicly; orders and receipts in account (unverified). Python bindings `rewerse` wrap a Go lib.

## FoodSavr mapping

Orders to purchases; products with EAN? (unverified); offers to offers; recipes to recipes.

## Risks and constraints

mTLS certificates must be extracted from the app, a gray area. Endpoints change. Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR.

## Existing work

`ByteSizedMarius/rewerse-engineering`, `yannick-cw/korb`, `adridevelopsthings/rewe_rs` (stale), `FaserF/ha-rewe`, `foo-git/rewe-discounts`.

## Sources

- https://pypi.org/project/rewerse/ — Python bindings
- https://github.com/yannick-cw/korb — basket CLI
- https://docs.rs/crate/rewe/latest/source/src/paths.rs — Rust crate paths
- https://www.github.com/FaserF/ha-rewe — Home Assistant
- https://github.com/foo-git/rewe-discounts/releases — offers scraper
