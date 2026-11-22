---
id: dk-aarstiderne
name: Aarstiderne
scope: dk
category: meal-kits
operator: Aarstiderne A/S
access: [export, bot]
auth: username-password
data: [orders, recipes]
item_level: true
cost: unknown
user_base: Organic fruit, vegetable and meal-kit subscription in Denmark (size unverified)
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Aarstiderne

Danish organic produce and meal-kit subscription. The app shows next week's menu and recipes and lets users view and change upcoming orders. No public or private API was found.

## Access

- **bot** — Only the logged-in web/app account; no documented API, no GitHub client, no MCP server found (searches returned nothing).
- **export** — A GDPR data request is the only likely bulk route (format unverified).
- The app lists menus, recipes and upcoming deliveries; whether past-order history exists is not documented ([App Store](https://apps.apple.com/us/app/id568066035)).

## Data

Weekly box contents and recipes (in-app). Nutrition PDF for three kits is public ([PDF](https://www.aarstiderne.com/media/1177/ernaeringssammensaetningen-i-tre-populaere-maaltidskasser-fra-aarstiderne.pdf)).

## FoodSavr mapping

Upcoming box contents could seed inventory/meal plan; recipes map to plans. Needs a user-driven copy or scraper.

## Risks and constraints

Scraping an account area breaches ToS risk; contents change weekly; substitutions.

## Existing work

None found.

## Sources

- https://apps.apple.com/us/app/id568066035
- https://shape.dk/aarstiderne
