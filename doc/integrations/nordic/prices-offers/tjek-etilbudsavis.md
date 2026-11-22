---
id: nordic-tjek-etilbudsavis
name: Tjek (eTilbudsavis / Mattilbud)
scope: nordic
category: prices-offers
operator: Tjek A/S
access: [api-public, api-private]
auth: api-key
data: [offers, prices, products]
item_level: true
cost: unknown
user_base: Flyer apps in Denmark (eTilbudsavis), Norway (Mattilbud) and others; Tjek claims 7.7 billion publication pages per year via its API
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Tjek (eTilbudsavis)

Flyer and offer aggregator behind eTilbudsavis (DK) and Mattilbud (NO). Exposes current catalogues and offers per retailer ("dealer") and store. Gives FoodSavr a Nordic-wide offers feed, not purchases.

## Access

- **api-public** — JSON API at `squid-api.tjek.com`: `GET /v2/catalogs` (filter by dealer/store), `GET /v2/catalogs/{id}/pages`, `GET /v2/offers` (by catalog), `POST /v4/rpc/get_offer_products`. API key comes from creating an app in the Tjek CMS, which is publisher-oriented, so open third-party access is unclear (unverified). Source: [Tjek integration docs](https://help.tjek.com/integration/api) (seen in search results; page not fetchable at research time).
- **api-private** — Community code uses the undocumented eTilbudsavis API, e.g. Home Assistant [hacs-etilbudsavis](https://awesome.ecosyste.ms/projects/github.com%2Fmacokay%2Fhacs-etilbudsavis). An Apify Coop DK actor uses the Tjek offers API ([Apify](https://apify.com/studio-amba/coop-scraper.md)).
- Tjek says to contact services@tjek.com to start using the APIs, so access is not fully self-serve ([APIs and SDKs](https://tjek.com/apis-and-sdks)). Auth header is `X-Api-Key`.
- No MCP server found.

## Data

Catalogues, pages, offers (heading, price, validity, dealer, store). Product details per offer via RPC. EAN presence unknown. Current offers only, no history.

## FoodSavr mapping

Offers -> offer hints on shopping-list items (fuzzy match by name/category). No purchase or inventory data.

## Risks and constraints

- [Terms](https://tjek.com/terms) govern API use; commercial reuse likely restricted (unverified).
- Undocumented endpoints can change.
- Offer text is marketing copy, so matching is imprecise.

## Existing work

Home Assistant integration (above); Apify scrapers; [BE-CH/tilbudstracker](https://github.com/BE-CH/tilbudstracker).

## Sources

- https://tjek.com/apis-and-sdks — official APIs and SDKs page
- https://help.tjek.com/integration/api — API docs (from search result)
- https://tjek.com/terms — terms
- https://apify.com/studio-amba/coop-scraper.md — scraper using Tjek API
