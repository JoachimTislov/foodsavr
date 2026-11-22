---
id: ca-loblaw-pc-optimum
name: Loblaw / PC Optimum / PC Express
scope: ca
category: grocery-retail
operator: Loblaw Companies Ltd.
access: [api-private, bot]
auth: session-cookie
data: [products, prices, offers]
item_level: true
cost: free
user_base: Canada's largest grocer; PC Optimum ~16M members (unverified)
tos_risk: high
fit: 3
status: researched
last_verified: 2026-11-21
---

# Loblaw / PC Optimum / PC Express

No public API. PC Express (Loblaws, Superstore, No Frills, etc.) uses a backend-for-frontend API; scrapers exist. PC Optimum points history is account-only.

## Access

- **api-private** — PC Express BFF (api.pcexpress.ca per a search hint, unverified); unofficial Apify actors for prices and store locations.
- **bot** — Python pickup-slot checker shmick/pcexpress-pickup.

## Data

Product, price, PC Optimum offers; store locations.

## FoodSavr mapping

Enrichment and offers; order history through account scraping (unverified).

## Risks and constraints

Unofficial; terms unreviewed.

## Existing work

- https://github.com/shmick/pcexpress-pickup

## Sources

- https://apify.com/sunny_eternity/loblaws-grocery-scraper — notes shared Loblaws API
- https://apify.com/aitorsm/pcexpress-product-scraper/api — scraper
- https://github.com/shmick/pcexpress-pickup (via repos.ecosyste.ms) — script
