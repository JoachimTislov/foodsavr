---
id: eu-deliveroo
name: Deliveroo
scope: eu
category: food-delivery
operator: Deliveroo plc (acquired by DoorDash 2025, unverified)
access: [export, api-partner, bot]
auth: oauth2
data: [orders]
item_level: true
cost: free
user_base: Millions of users in UK, IE, FR, IT, BE, AE, others
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Deliveroo

Restaurant and grocery delivery. Official developer portal covers the Partner Platform (Order API, webhooks), Retail Platform (Picking API) and Signature API, all for merchants.

## Access

- **api-partner** — Deliveroo Developer Portal: Order API and webhooks for restaurants/POS partners.
- **export** — GDPR data request for the consumer's order history (unverified).
- **bot** — scraping of the account order history.

## Data

Partner Order API gives merchant-side orders. Consumer data via export only.

## FoodSavr mapping

Meal logging; low inventory value. Grocery partners (Retail Platform) are merchant-side.

## Risks and constraints

Partner agreement required; no consumer API.

## Existing work

None verified.

## Sources

- https://api-docs.deliveroo.com — developer portal
- https://api-docs.deliveroo.com/v2.0/docs/introduction — introduction
