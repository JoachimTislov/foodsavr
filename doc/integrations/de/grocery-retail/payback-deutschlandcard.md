---
id: de-payback-deutschlandcard
name: Payback and Deutschlandcard
scope: de
category: grocery-retail
operator: Payback GmbH / Deutschlandcard
access: [export, api-private]
auth: username-password
data: [purchases, offers]
item_level: false
cost: free
user_base: Payback ~30M+ users in DE (unverified); Deutschlandcard ~ millions
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Payback and Deutschlandcard

German multi-partner loyalty schemes (Payback: REWE, Penny, dm, Rossmann; Deutschlandcard: Netto and others). Purchase data is partner-level with limited item detail.

## Access

- **export** — Payback/Deutschlandcard data request.
- **api-private** — a Telegram bot reportedly uses reverse-engineered APIs for coupon activation (GitHub topic page); no purchase-history client found.

## Data

Point accruals per partner and basket value; item detail unverified.

## FoodSavr mapping

Merchant-level purchases only; offers via coupons.

## Risks and constraints

Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR.

## Existing work

Payback coupon bots (not verified).

## Sources

- https://www.github.com/topics/payback — related projects
