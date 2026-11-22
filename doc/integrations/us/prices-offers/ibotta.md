---
id: us-ibotta
name: Ibotta
scope: us
category: prices-offers
operator: Ibotta, Inc.
access: [api-partner]
auth: api-key
data: [offers]
item_level: true
cost: partner
user_base: US cash-back app
tos_risk: low
fit: 2
status: researched
last_verified: 2026-11-21
---

# Ibotta

Cash-back offers app; its Ibotta Performance Network provides white-labelled offers to retailers and publishers via managed partner onboarding.

## Access

- **api-partner** — IPN (ipn.ibotta.com) white-labelled offer API; no public self-serve developer API (per API Evangelist). A Product API OpenAPI doc is listed on Apideck-style catalogs with a service bearer token.

## Data

Offers and product-level rebates.

## FoodSavr mapping

Offers input only if a partner deal exists.

## Risks and constraints

Commercial agreement.

## Existing work

- None.

## Sources

- https://ipn.ibotta.com/integrating-with-the-IPN — IPN integration
- https://providers.apievangelist.com/providers/ibotta/ — no public API
- https://apis.io/providers/ibotta/ — listing
