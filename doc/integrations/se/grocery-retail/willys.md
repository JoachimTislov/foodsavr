---
id: se-willys
name: Willys (Axfood)
scope: se
category: grocery-retail
operator: Axfood AB
access: [api-private, mcp, bot]
auth: bankid
data: [purchases, line-items, products, prices, orders]
item_level: true
cost: free
user_base: Axfood's discount chain and web shop; Willys Plus members (size unknown)
tos_risk: high
fit: 4
status: researched
last_verified: 2026-11-21
---

# Willys (Axfood)

Discount grocery chain and web shop (willys.se) in the Axfood group. No official API. Reverse-engineered clients cover search and cart; a receipt tool covers purchase history via BankID.

## Access

- **api-private** — `ErikHellman/willys-agent` (TypeScript CLI/library): login with personnummer+password (cookie/CSRF session, AES-encrypted credentials), product search, category tree, cart add/remove/clear. No purchase history in its README.
- **api-private (receipts)** — `khessman/matmetrics` crate `kvitto-willys`: BankID login (a WAF blocks plain HTTP clients and headless browsers, so it drives a visible Chromium) and fetches receipts for Willys and Hemköp on the shared Axfood/Hybris backend. Article numbers and normalised names are used; EAN and quantity fields were not confirmed.
- **mcp / agent skills** — willys-agent ships Claude Code skills; `simonnordberg/veckomenyn` is a meal planner with a Willys.se backend.
- **bot** — hosted Apify actor for products and prices (name, brand, price, unit price, weight, category; EAN not listed).

## Data

Products with prices, categories, unit price; receipts with article number per line (shape not verified).

## FoodSavr mapping

Receipts to `LineItem` (purchases) once the BankID flow is solved; web-shop search for price/enrichment; cart push from shopping list.

## Risks and constraints

- WAF/bot protection on login; private API; terms likely forbid scraping (unverified).
- BankID automation needs a user-present step per session; matmetrics keeps sessions in memory only.

## Existing work

- https://github.com/ErikHellman/willys-agent
- https://github.com/khessman/matmetrics and https://github.com/khessman/kvitto-willys
- https://github.com/simonnordberg/veckomenyn
- https://github.com/whame/parsewillya (receipt parser)

## Sources

- https://raw.githubusercontent.com/ErikHellman/willys-agent/HEAD/README.md — capabilities and auth
- https://raw.githubusercontent.com/khessman/matmetrics/HEAD/README.md — BankID receipts, WAF note
- https://apify.com/studio-amba/willys-scraper — public product data fields
