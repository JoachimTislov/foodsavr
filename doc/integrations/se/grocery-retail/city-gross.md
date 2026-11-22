---
id: se-city-gross
name: City Gross
scope: se
category: grocery-retail
operator: unknown
access: [bot, feed]
auth: none
data: [products, prices]
item_level: true
cost: unknown
user_base: Swedish hypermarket chain (size unknown)
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# City Gross

Hypermarket chain, not part of Axfood. No official API or member purchase access found.

## Access

- **feed / third-party API** — Primat API lists City Gross daily prices per store (see `se-primat`).
- **bot** — small GitHub scrapers (`kazooxd/CityGross_Scraper`, `radu0100/citygross.se_Scraper`); `johannahulten/shop-with-gorcy` links City Gross shopping with Grocy.

## Data

Products and prices only.

## FoodSavr mapping

Price/offer enrichment; no purchases.

## Risks and constraints

Scraping terms unverified; hobby repos unmaintained.

## Existing work

- https://github.com/kazooxd/CityGross_Scraper
- https://github.com/johannahulten/shop-with-gorcy

## Sources

- https://raw.githubusercontent.com/ostwilkens/primat-api/HEAD/README.md — City Gross prices covered
