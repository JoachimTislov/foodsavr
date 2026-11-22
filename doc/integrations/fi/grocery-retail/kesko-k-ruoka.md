---
id: fi-kesko-k-ruoka
name: Kesko K-Ruoka (K-Plussa, K-Ostokset)
scope: fi
category: grocery-retail
operator: Kesko Oyj
access: [api-partner, api-private, bot]
auth: unknown
data: [products, prices, purchases, offers]
item_level: true
cost: unknown
user_base: Finland's largest grocery group (K-Citymarket, K-Supermarket, K-Market); K-Plussa loyalty is very widely held (size unverified)
tos_risk: high
fit: 4
status: researched
last_verified: 2026-11-21
---

# Kesko K-Ruoka

Kesko runs the K-Ruoka web shop and app, the K-Plussa loyalty programme and the K-Ostokset purchase-history service, which Kesko says shows nutritional values of grocery purchases ([Kesko news 2020](https://www.kesko.fi/en/media/news-and-releases/news/2020/k-group-introduces-new-service-k-ostokset-now-shows-the-nutritional-values-of-your-grocery-purchases)). Item-level purchase data exists but no consumer-facing API was found.

## Access

- **api-partner** — Kesko Developer Portal (Azure API Management) at [k-developer.kesko.fi](https://k-developer.kesko.fi) with a separate test portal; categories "Grocery trade", "Building and technical trade", "Car trade". Sign-up and API subscription; which grocery APIs exist and who may subscribe was not readable (unverified).
- **api-private** — K-Ruoka web uses `/kr-api/v2/product-search/` (up to 100 products per query, no pagination) per an Apify actor's description; site runs Cloudflare bot management ([Apify](https://apify.com/studio-amba/k-ruoka-fi-scraper.md)). No reverse-engineered K-Plussa/K-Ostokset client found.
- **bot** — Possible against the user's K-Ruoka account; untested.
- **export** — GDPR request to Kesko for K-Plussa data (format unverified).
- No MCP server found.

## Data

Products with EAN, brand, category, unit price (Apify). K-Ostokset: purchase history with product lines (per Kesko news; fields unverified).

## FoodSavr mapping

K-Ostokset purchases to `LineItem`; product search for EAN enrichment and prices.

## Risks and constraints

No documented consumer access; ToS and anti-bot measures; Finnish data-protection rules on loyalty data.

## Existing work

Apify scraper only.

## Sources

- https://k-developer.kesko.fi
- https://apify.com/studio-amba/k-ruoka-fi-scraper.md
- https://www.kesko.fi/en/media/news-and-releases/news/2020/k-group-introduces-new-service-k-ostokset-now-shows-the-nutritional-values-of-your-grocery-purchases
