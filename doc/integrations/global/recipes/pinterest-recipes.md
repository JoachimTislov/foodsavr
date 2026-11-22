---
id: global-pinterest-recipes
name: Pinterest (recipe pins)
scope: global
category: recipes
operator: Pinterest
access: [api-public]
auth: oauth2
data: [recipes]
item_level: false
cost: free
user_base: Hundreds of millions of users; large recipe content
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# Pinterest (recipe pins)

Pinterest boards contain saved recipe pins that link to recipe sites. Pinterest API v5 lets users authorise access to their boards and pins; Rich Pins carry schema.org-style recipe metadata.

## Access

- **api-public** - Pinterest API v5 `https://api.pinterest.com/v5/` (boards, pins) with OAuth 2.0; app review required for access beyond trial (verify).

## Data

Pins: title, description, link, media; recipe fields are only on the linked site (parse via schema.org scraping).

## FoodSavr mapping

Import user's saved recipe boards as links, then parse with schema.org scraping.

## Risks and constraints

- App review, API access tiers; content is third-party.

## Existing work

- No MCP server verified.

## Sources

- https://developers.pinterest.com/docs/api/v5/ - API docs
