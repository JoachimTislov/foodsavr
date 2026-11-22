---
id: us-doordash
name: DoorDash
scope: us
category: food-delivery
operator: DoorDash, Inc.
access: [api-partner, export]
auth: oauth2
data: [orders]
item_level: false
cost: partner
user_base: Largest US food delivery base
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# DoorDash

DoorDash's developer portal offers Drive (delivery-as-a-service) and merchant integrations, not consumer order history.

## Access

- **api-partner** — developer.doordash.com Drive API; JWT auth (developer ID, key ID, signing secret); production access restricted/certified.
- **export** — consumer data request (unverified).

## Data

Delivery quotes/status for merchants.

## FoodSavr mapping

Consumer orders not available; order confirmation emails are the realistic source (see email categories).

## Risks and constraints

Partner-gated.

## Existing work

- None relevant.

## Sources

- https://developer.doordash.com/docs/drive/overview/faqs — Drive access restricted
- https://developer.doordash.com/docs/welcome — portal
