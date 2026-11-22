---
id: de-netto
name: Netto Marken-Discount
scope: de
category: grocery-retail
operator: Edeka Group
access: [export, bot, api-private]
auth: unknown
data: [purchases, offers]
item_level: false
cost: unknown
user_base: German discount chain; Netto app, Deutschlandcard
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Netto Marken-Discount

Netto Marken-Discount in Germany. No public developer API found. Loyalty/app purchase history may be exportable via GDPR; Payback/Deutschlandcard hold purchase data across partners.

## Access

- **api-private** — apps use private APIs; none documented in public repos found by search (unverified).
- Payback/Deutschlandcard reverse-engineered API exists only for coupon activation (a Telegram bot, per a GitHub topic page).
- **export** — GDPR/GDPR-style data-access request (Art. 15/20) to the operator; format and item-level detail vary and delivery can take up to a month (unverified per operator).

## Data

Not verified. Loyalty-app purchase history, where offered, is typically per-visit with line items (unverified). No public schema found.

## FoodSavr mapping

Purchases/orders to `LineItem` where line items are exposed; offers to the offers class. EAN availability unknown. No expiry data; FoodSavr would estimate shelf life from product category.

## Risks and constraints

Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR. Official public API: none found.

## Existing work

None verified.

## Sources

- https://www.github.com/topics/payback — Payback related projects (coupon bots)
