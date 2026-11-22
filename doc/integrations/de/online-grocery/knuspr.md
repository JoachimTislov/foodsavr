---
id: de-knuspr
name: Knuspr
scope: de
category: online-grocery
operator: Rohlik Group
access: [api-private, bot]
auth: unknown
data: [orders, products, prices]
item_level: true
cost: free
user_base: Online grocer in DE; same platform as Rohlik (CZ), Kifli (HU) etc.
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Knuspr

German online grocer on the Rohlik platform. An Apify scraper uses its internal REST API for products, prices, stock and categories.

## Access

- **api-private** — internal REST API (used by Apify scraper); account endpoints unverified.
- **bot** — scraping.

## Data

Product details, pricing, stock and category paths.

## FoodSavr mapping

Products/prices for enrichment; account orders would map to purchases (unverified).

## Risks and constraints

Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR. Same platform serves other countries.

## Existing work

Apify `studio-amba/knuspr-scraper`.

## Sources

- https://apify.com/studio-amba/knuspr-scraper — scraper notes
