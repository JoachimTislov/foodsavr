---
id: dk-coop-dk
name: Coop Danmark (Coop app)
scope: dk
category: grocery-retail
operator: Coop Danmark A/S
access: [feed, bot]
auth: unknown
data: [offers, prices, products]
item_level: true
cost: unknown
user_base: Large; Kvickly, SuperBrugsen, Brugsen, Irma, 365discount; Coop app with Scan & Pay (size unverified)
tos_risk: high
fit: 3
status: researched
last_verified: 2026-11-21
---

# Coop Danmark

Danish cooperative grocery group. The Coop app offers Scan & Pay and member offers. No public developer API and no documented private API found. FoodSavr's Coop stub targets Norway; the Danish app is a different service.

## Access

- **none official** — no developer portal found; the app listing gives only a feedback address ([App Store DK](https://apps.apple.com/dk/app/id698632628)).
- **feed** — Offers flow through the Tjek API, which an Apify actor uses for Kvickly, SuperBrugsen, Brugsen and 365discount ([Apify](https://apify.com/studio-amba/coop-scraper.md)). See `nordic/prices-offers/tjek-etilbudsavis.md`.
- **bot** — Catalogue scrapers for coop365.dk exist on Apify ([coop365 scraper](https://apify.com/blackfalcondata/coop365-scraper.md)).
- Reverse-engineering exists only for Coop Norway (Auth0/OIDC, [gist](https://gist.github.com/HelgeSverre/80a7f34f874336324184a0c513c2e6a2)). Whether the Danish app shares that backend is unverified.

## Data

Public offers and catalogue prices. Purchase history or receipts in the app: access path unknown.

## FoodSavr mapping

Offers via Tjek. Purchases would need an unverified reverse-engineered client or a GDPR export.

## Risks and constraints

Reverse engineering likely breaches ToS. GDPR Art. 15 request is the legal export route (format unverified for Coop DK).

## Existing work

Apify scrapers only. No MCP server or open-source Danish app client found.

## Sources

- https://apps.apple.com/dk/app/id698632628
- https://apify.com/studio-amba/coop-scraper.md
- https://apify.com/blackfalcondata/coop365-scraper.md
- https://gist.github.com/HelgeSverre/80a7f34f874336324184a0c513c2e6a2
