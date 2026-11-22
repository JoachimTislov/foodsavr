---
id: dk-just-eat-dk
name: Just Eat Denmark
scope: dk
category: food-delivery
operator: Just Eat Takeaway.com
access: [api-partner, api-private]
auth: oauth2
data: [orders]
item_level: true
cost: partner
user_base: Large Danish takeaway platform (size unverified)
tos_risk: high
fit: 1
status: researched
last_verified: 2026-11-21
---

# Just Eat Denmark

Takeaway marketplace. Restaurant orders are not grocery inventory, so value is low. See `no/food-delivery/just-eat-no.md` for the sister market.

## Access

- **api-partner** — Just Eat publishes partner/restaurant APIs; the catalogue lists a server `i18n.api.just-eat.io` for DK, ES, IE, IT and NO. A consumer orders endpoint is documented in the UK API (`GET /consumer/me/orders/uk`, user JWT required). A DK consumer-orders endpoint was not confirmed. ([apis.io](https://apis.io/providers/just-eat/), [apis.guru](https://apis.guru/apis/just-eat.co.uk))
- **api-private** — No Danish community client found.
- No MCP server found.

## Data

Orders with items and prices (UK API shape; DK unverified).

## FoodSavr mapping

Little: restaurant meals do not create stock; at most "meal eaten" for consumption tracking.

## Risks and constraints

Partner agreement or user-token scraping breaching ToS.

## Existing work

None found for DK.

## Sources

- https://apis.io/providers/just-eat/
- https://apis.guru/apis/just-eat.co.uk
