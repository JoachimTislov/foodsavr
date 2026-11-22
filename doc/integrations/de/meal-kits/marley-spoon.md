---
id: de-marley-spoon
name: Marley Spoon
scope: de
category: meal-kits
operator: Marley Spoon SE
access: [export, bot]
auth: unknown
data: [orders, recipes, plans]
item_level: false
cost: unknown
user_base: Recipe box in DE, NL, BE, AT, US, AU; sister brand Dinnerly
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Marley Spoon

Recipe box with weekly menus. No public API found.

## Access

- **bot** — site automation.
- **export** — GDPR/GDPR-style data-access request (Art. 15/20) to the operator; format and item-level detail vary and delivery can take up to a month (unverified per operator).

## Data

Not verified. Loyalty-app purchase history, where offered, is typically per-visit with line items (unverified). No public schema found.

## FoodSavr mapping

Purchases/orders to `LineItem` where line items are exposed; offers to the offers class. EAN availability unknown. No expiry data; FoodSavr would estimate shelf life from product category.

## Risks and constraints

Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR. Official public API: none found.

## Existing work

None found.

## Sources

- https://marleyspoon.de — operator site
