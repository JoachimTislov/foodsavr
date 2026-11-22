---
id: ca-flipp
name: Flipp
scope: ca
category: prices-offers
operator: Flipp Corporation (Wishabi)
access: [api-private, bot]
auth: none
data: [offers, prices]
item_level: true
cost: unknown
user_base: ~100M+ shoppers (corporate claim)
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# Flipp

Digital flyer aggregator for Canada and the US. No public developer API; unofficial scrapers use public price-search endpoints.

## Access

- **api-private** — public unauthenticated price-search/flyer endpoints used by Apify actors (vendor claim, unverified).
- **bot** — Kiizon/flippscrape, FriendlyUser/flipp_flyer_parser.

## Data

Flyer items by postal code and merchant: name, price, validity dates, flyer ID.

## FoodSavr mapping

Offers by postal code to prompt shopping-list suggestions.

## Risks and constraints

Not endorsed by Flipp; retailer-feed deals are partner-only.

## Existing work

- https://github.com/Kiizon/flippscrape
- https://github.com/FriendlyUser/flipp_flyer_parser

## Sources

- https://providers.apievangelist.com/providers/flipp-wishabi/ — no public API
- https://github.com/Kiizon/flippscrape — scraper
- https://apify.com/haketa/flipp-scraper.md — hosted actor
