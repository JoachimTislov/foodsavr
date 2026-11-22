---
id: gb-mindful-chef
name: Mindful Chef
scope: gb
category: meal-kits
operator: Mindful Chef Ltd
access: [export, bot]
auth: unknown
data: [orders, recipes]
item_level: false
cost: unknown
user_base: UK healthy recipe box
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Mindful Chef

UK recipe-box service. No public or official API found.

## Access

- **bot** — site automation only.
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

- https://www.mindfulchef.com — operator site (no developer portal found)
