---
id: eu-kaufland
name: Kaufland / Kaufland Card
scope: eu
category: grocery-retail
operator: Schwarz Gruppe (Kaufland)
access: [export, bot]
auth: unknown
data: [purchases, offers]
item_level: false
cost: unknown
user_base: Kaufland in ~8 countries (DE, CZ, SK, PL, RO, BG, HR, MD); Kaufland Card app
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Kaufland / Kaufland Card

Hypermarket chain with a loyalty card in the Kaufland app (offers, coupons). Receipt/purchase history in the app is not confirmed. The official Kaufland APIs found are for marketplace sellers only.

## Access

- **api-partner** — Kaufland Marketplace Seller API 2.0 (online marketplace, sellers only; not store purchases).
- **export** — GDPR/GDPR-style data-access request (Art. 15/20) to the operator; format and item-level detail vary and delivery can take up to a month (unverified per operator).

## Data

Not verified. Loyalty-app purchase history, where offered, is typically per-visit with line items (unverified). No public schema found.

## FoodSavr mapping

Purchases/orders to `LineItem` where line items are exposed; offers to the offers class. EAN availability unknown. No expiry data; FoodSavr would estimate shelf life from product category.

## Risks and constraints

Seller API does not expose consumer purchases. Anti-bot protection blocks scraping. Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR.

## Existing work

Search for shopper-side Kaufland Card clients found none. Scrapers face Cloudflare/DataDome.

## Sources

- https://sellerapi.kaufland.com — marketplace seller API
- https://apify.com/studio-amba/kaufland-de-scraper.md — scraper notes anti-bot
