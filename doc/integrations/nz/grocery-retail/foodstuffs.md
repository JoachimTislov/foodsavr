---
id: nz-foodstuffs
name: Foodstuffs (New World, PAK'nSAVE)
scope: nz
category: grocery-retail
operator: Foodstuffs North/South Island
access: [api-private, bot]
auth: session-cookie
data: [products, prices, purchases, lists]
item_level: true
cost: free
user_base: ~NZ half of grocery market (unverified)
tos_risk: high
fit: 4
status: researched
last_verified: 2026-11-21
---

# Foodstuffs (New World, PAK'nSAVE)

No public API. Gists document Android-app endpoints including previous purchases, shopping lists and cart; scrapers face Turnstile on the web.

## Access

- **api-private** — Arefu gists (Foodstuffs North Island API): cart, previous product purchases, shopping lists, product search.
- **bot** — nz-supermarket-scraper (Playwright, guest catalogue only).

## Data

Product search, previous purchases list, shopping lists.

## FoodSavr mapping

Previous purchases to `LineItem` (if endpoint still works); shopping-list sync (unverified).

## Risks and constraints

Unofficial; endpoints may be blocked.

## Existing work

- https://gist.github.com/Arefu/b12d83a5dffb6573a1b1907044ad8de4

## Sources

- https://gist.github.com/Arefu/b12d83a5dffb6573a1b1907044ad8de4 — endpoints
- https://gist.github.com/Arefu/b94ea1942c7fa898c2e473a75c5c67cf — North Island API
- https://skillsmp.com/creators/maxazure/nz-supermarket-scraper — scraper
