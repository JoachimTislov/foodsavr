---
id: eu-carrefour
name: Carrefour (group)
scope: eu
category: grocery-retail
operator: Carrefour SA
access: [api-partner, bot, export]
auth: unknown
data: [prices, products, offers]
item_level: false
cost: unknown
user_base: Carrefour in FR, ES, IT, BE, PL, RO and others; large loyalty programmes
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Carrefour (group)

Group-level entry; see per-country entries (gb has none, `fr/grocery-retail/carrefour.md` covers France). Carrefour publishes no general public product/price API; Carrefour Italia has a partner developer portal, Carrefour Links serves brands, and marketplace sellers use Mirakl.

## Access

- **api-partner** — Carrefour Italia partner portal, Carrefour Links (brands), Mirakl (marketplace sellers) per a third-party summary (unverified).
- **export** — GDPR/GDPR-style data-access request (Art. 15/20) to the operator; format and item-level detail vary and delivery can take up to a month (unverified per operator).

## Data

Not verified. Loyalty-app purchase history, where offered, is typically per-visit with line items (unverified). No public schema found.

## FoodSavr mapping

Purchases/orders to `LineItem` where line items are exposed; offers to the offers class. EAN availability unknown. No expiry data; FoodSavr would estimate shelf life from product category.

## Risks and constraints

Partner access is for suppliers/sellers. DataDome anti-bot on carrefour.fr. Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR.

## Existing work

No unofficial GitHub client for consumer accounts found. Hosted scrapers (Apify, parse.bot) cover catalogue, prices, EAN, promotions.

## Sources

- https://clawhub.ai/scavio-ai/skills/carrefour-api — summary of access options
- https://helpcenter.channable.com/hc/en-us/articles/8506378321426-Setting-up-a-Carrefour-France-API — Mirakl marketplace
