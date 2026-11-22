---
id: dk-rema-1000-dk
name: REMA 1000 Denmark
scope: dk
category: grocery-retail
operator: REMA 1000 Danmark A/S
access: [api-private, feed]
auth: none
data: [products, prices, offers]
item_level: true
cost: free
user_base: Denmark's discount chain (size unverified)
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# REMA 1000 Denmark

Danish arm of Rema 1000. It is not the Norwegian Æ app that FoodSavr already supports (`no/grocery-retail/rema-1000.md`). Only catalogue and offer data found for DK; no purchase history.

## Access

- **api-private** — The web shop `shop.rema1000.dk` uses a product-search API, called directly by an Apify actor that returns prices and EAN. The site is geo-blocked outside Denmark but the product API reportedly is not. No auth seen. ([Apify](https://apify.com/studio-amba/rema1000-dk-scraper), [API page](https://apify.com/studio-amba/rema1000-dk-scraper/api))
- **feed** — Offers via Tjek (see `nordic/prices-offers/tjek-etilbudsavis.md`); [BE-CH/tilbudstracker](https://github.com/BE-CH/tilbudstracker) scrapes Rema offers via an Algolia index.
- No official developer API, DK loyalty API or MCP server found.

## Data

Products with EAN, price, category (per the actor description); current offers. No per-store stock.

## FoodSavr mapping

Enrichment (EAN to name) and offers. No purchases.

## Risks and constraints

Undocumented endpoints change; scraping terms unverified; do not assume the Norwegian Æ auth applies.

## Existing work

Apify actors; tilbudstracker.

## Sources

- https://apify.com/studio-amba/rema1000-dk-scraper
- https://apify.com/studio-amba/rema1000-dk-scraper/api
- https://github.com/BE-CH/tilbudstracker
