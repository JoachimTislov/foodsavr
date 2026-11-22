---
id: fr-monoprix
name: Monoprix
scope: fr
category: grocery-retail
operator: Monoprix SA (Casino/Galeries Lafayette)
access: [bot, export]
auth: unknown
data: [prices, products, offers, purchases]
item_level: false
cost: unknown
user_base: France urban supermarkets; app and delivery
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Monoprix

Monoprix in France. No public consumer API found; hosted scrapers cover public catalogue and prices. Account purchase history via app/export (unverified).

## Access

- **bot** — public catalogue scrapers (see Existing work).
- **export** — GDPR/GDPR-style data-access request (Art. 15/20) to the operator; format and item-level detail vary and delivery can take up to a month (unverified per operator).

## Data

Not verified. Loyalty-app purchase history, where offered, is typically per-visit with line items (unverified). No public schema found.

## FoodSavr mapping

Purchases/orders to `LineItem` where line items are exposed; offers to the offers class. EAN availability unknown. No expiry data; FoodSavr would estimate shelf life from product category.

## Risks and constraints

Anti-bot protection (DataDome on Carrefour, Auchan, Intermarché). Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR.

## Existing work

One scraper mentioned (unverified); `chriSmile0/Scrapper` notes Monoprix has no protection.

## Sources

- https://apify.com/studio-amba/intermarche-fr-scraper — Intermarché scraper
- https://apify.com/abotapi/auchan-fr-scraper.md — Auchan scraper
- https://apify.com/abotapi/leclerc-fr-scraper.md — Leclerc scraper
- https://www.data.gouv.fr/organizations/auchan-france/dataservices — Auchan open data
- https://parse.bot/marketplace/cc2b5dad-f412-4bee-9b32-fd5f482dea10/carrefour-fr-api — Carrefour third-party API
