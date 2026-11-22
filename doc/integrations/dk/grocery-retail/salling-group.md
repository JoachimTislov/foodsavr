---
id: dk-salling-group
name: Salling Group (Netto, Føtex, Bilka)
scope: dk
category: grocery-retail
operator: Salling Group A/S
access: [api-public]
auth: api-key
data: [products, prices, offers]
item_level: true
cost: free
user_base: Denmark's largest grocery group (Netto, Føtex, Bilka); loyalty via Salling Group app (size unverified)
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Salling Group (Netto, Føtex, Bilka)

Salling Group runs a free public developer portal with store, markdown and other APIs. It is not a purchase-history source: no consumer receipts or loyalty-history API was found. Useful for store lookup and clearance offers; see `dk/food-waste/salling-food-waste-api.md` for the markdown API.

## Access

- **api-public** — Developer portal `developer.sallinggroup.dev` (old `developer.sallinggroup.com` redirects there). Sign-in with a Salling Group Profile; "free and painless sign-up, no card required". The landing page names store data across brands/countries, job vacancies and markdowns. Bearer-token auth is stated for the food waste API. Rate limits and terms were not readable at research time (unverified). ([portal](https://developer.sallinggroup.dev/?from-old=true))
- A product-search/suggestions API and a loyalty/receipt API were not confirmed (unverified).
- **api-private** — Salling Group consumer app: no reverse-engineered client found.

## Data

Stores (brand, address, coordinates, opening hours; exact fields unverified), clearance offers. No customer data.

## FoodSavr mapping

Offers and store lookup only. No purchases, no inventory.

## Risks and constraints

Terms apply per key; check commercial-use limits before shipping. Rate limits unknown.

## Existing work

Community clients are listed in the food-waste entry.

## Sources

- https://developer.sallinggroup.dev/?from-old=true — portal landing
- https://developer.sallinggroup.com/api-reference — API reference (redirects; seen in search results)
