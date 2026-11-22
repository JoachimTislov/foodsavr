---
id: fi-resq-club
name: ResQ Club
scope: fi
category: food-waste
operator: ResQ Club Oy
access: [none]
auth: unknown
data: [offers, orders]
item_level: false
cost: unknown
user_base: Surplus-food marketplace in Finland, Sweden, Estonia, Germany; tens of thousands of monthly users per app listing
tos_risk: medium
fit: 2
status: researched
last_verified: 2026-11-21
---

# ResQ Club

Marketplace where restaurants, cafes and shops sell surplus food (typically meals and bags) at about half price, collected at the venue. Orders are mostly ready portions, not pantry stock. No consumer or partner data API found.

## Access

- **none** — No public developer API. A separate ResQ Partner app serves sellers ([App Store](https://apps.apple.com/nl/app/resq-partner/id1204880958)). Consumer order history exists in-app; export route unverified.
- No GitHub client or MCP server found.

## Data

Offers by location and pickup window (in-app); orders. Item detail is generally a portion/bag description (unverified).

## FoodSavr mapping

Offers class (nearby surplus), and "food picked up" as short-life inventory entered manually.

## Risks and constraints

No sanctioned access; scraping the app breaches ToS risk.

## Existing work

None found.

## Sources

- https://apps.apple.com/fi/app/resq-club/id1069744707
- https://apps.apple.com/nl/app/resq-partner/id1204880958
- https://www.sitra.fi/en/cases/resq-club-redeems-surplus-food-from-restaurants-and-brings-it-to-consumers-plates-the-service-must-meet-the-needs-of-different-markets/
