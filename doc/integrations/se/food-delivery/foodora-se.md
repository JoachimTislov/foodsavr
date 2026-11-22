---
id: se-foodora
name: Foodora Sweden
scope: se
category: food-delivery
operator: Delivery Hero (Foodora)
access: [api-private, bot]
auth: username-password
data: [orders]
item_level: true
cost: free
user_base: Major Nordic food-delivery app; Sweden market
tos_risk: high
fit: 2
status: researched
last_verified: 2026-11-21
---

# Foodora Sweden

Restaurant takeaway and delivery. Orders are meals, not groceries; value for FoodSavr is mainly knowing a planned meal was replaced by takeaway.

## Access

- **api-private** — `steipete/ordercli` (CLI for Foodora and Deliveroo): Sweden preset (`--country SE`), email+password login with OTP/MFA, active orders, order history (`--json`), order details, reorder to cart. Falls back to a Playwright session or imported Chrome cookies when bot protection triggers. May hit rate limits or Cloudflare.
- Partner/POS integrations exist for restaurants, not consumer data (unverified).

## Data

Order history with items per order via ordercli JSON (field list not verified).

## FoodSavr mapping

Order history as consumption/meal log; low inventory value.

## Risks and constraints

Private API, bot protection, ToS breach likely.

## Existing work

- https://github.com/steipete/ordercli

## Sources

- https://raw.githubusercontent.com/steipete/ordercli/HEAD/README.md — SE support, features, caveats
