---
id: eu-aldi
name: Aldi (Nord, Süd, UK, others)
scope: eu
category: grocery-retail
operator: Aldi Nord / Aldi Süd groups
access: [feed, export, bot]
auth: unknown
data: [offers, prices]
item_level: false
cost: unknown
user_base: Aldi operates in ~12 European countries; apps differ per entity
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Aldi (Nord, Süd, UK, others)

Discount grocer with separate Aldi Nord and Aldi Süd companies and national apps (e.g. Aldi Süd app in DE, Aldi UK app). Loyalty/digital receipts are limited; Aldi mostly publishes weekly offers.

## Access

- **feed** — weekly offer flyers are public web pages/PDFs (no structured API found).
- **bot** — scraping of product and offer pages only.
- **export** — GDPR/GDPR-style data-access request (Art. 15/20) to the operator; format and item-level detail vary and delivery can take up to a month (unverified per operator).

## Data

Not verified. Loyalty-app purchase history, where offered, is typically per-visit with line items (unverified). No public schema found.

## FoodSavr mapping

Purchases/orders to `LineItem` where line items are exposed; offers to the offers class. EAN availability unknown. No expiry data; FoodSavr would estimate shelf life from product category.

## Risks and constraints

Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR. Official public API: none found.

## Existing work

No unofficial purchase-history client found (searches in 2026-11 found none). Aldi Nord/Süd/UK have no known account-bound receipt feature (unverified).

## Sources

- https://www.aldi-nord.de — operator site (no developer portal found)
- https://www.aldi-sued.de — operator site
