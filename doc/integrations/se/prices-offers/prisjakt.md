---
id: se-prisjakt
name: Prisjakt
scope: se
category: prices-offers
operator: Prisjakt (PriceSpy; Schibsted/Vend group, unverified)
access: [api-partner, bot]
auth: oauth2
data: [prices, products]
item_level: true
cost: partner
user_base: Large Nordic price comparison site; groceries are a minor category (unverified)
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Prisjakt

Price comparison mostly for electronics and household goods. A grocery-specific data source was not found, so value for FoodSavr is low.

## Access

- **api-partner** — Prisjakt Partner Search API at `api.schibsted.com/prisjakt/partner-search` (client credentials; cache at least 5 minutes), plus Click and Conversion and Insights APIs for partners, documented on the Vend/MuleSoft API portal. Terms require attribution and a link to Prisjakt/PriceSpy.
- **bot** — Apify scrapers for Prisjakt/PriceSpy.
- Merchant feeds (XML with EAN) flow in the other direction.

## Data

Product, price and offer listings per shop; EAN present in merchant feeds.

## FoodSavr mapping

Non-food price enrichment only; for groceries use `se-primat` or `se-matpriskollen`.

## Risks and constraints

Partner agreement needed; scraping against terms (unverified).

## Existing work

- https://apify.com/studio-amba/prisjakt-scraper

## Sources

- https://anypoint.mulesoft.com/exchange/portals/schibsted-etech-1/73a598fc-e854-4cb7-bea6-a4c899c8cb73/prisjakt-partner-search-api — Partner Search API
- https://vend.com/api-portal/73a598fc-e854-4cb7-bea6-a4c899c8cb73/prisjakt-click-api/minor/1.1/pages/.terms — attribution terms
- https://www.koongo.com/channels/prisjakt/ — merchant feed requirements (third party)
