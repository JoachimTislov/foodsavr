---
id: <scope>-<service>              # e.g. no-rema-1000
name: <Display name>
scope: <no | se | dk | nordic | eu | global | ...>
category: <category from README>
operator: <company behind the service>
access: [<api-public | api-partner | api-private | mcp | export | feed | bot | none>]
auth: <none | api-key | oauth2 | oauth2-pkce | oidc | bankid | session-cookie | username-password | unknown>
data: [<purchases | line-items | orders | offers | prices | products | nutrition | recipes | lists | plans | inventory>]
item_level: <true | false>         # does it expose individual products, not just totals?
cost: <free | freemium | paid | partner | unknown>
user_base: <rough size and region, or unknown>
tos_risk: <low | medium | high>     # risk of breaching terms with the chosen access
fit: <1-5>
status: researched
last_verified: <YYYY-MM-DD>
---

# <Display name>

One-paragraph summary: what the service is and what FoodSavr would get from it.

## Access

Per access method found, best first:

- **<method>** — endpoint/base URL, auth flow, rate limits, sandbox, SDKs, official vs community.

## Data

What is available and in what shape (fields, identifiers like EAN/GTIN, history depth, freshness). Include a trimmed example payload when known (no personal data, no secrets).

## FoodSavr mapping

How the data maps to FoodSavr input classes (purchases, orders, offers, recipes, lists, enrichment) and to `LineItem`. Note gaps (missing EAN, quantities, expiry).

## Risks and constraints

Terms of service, legal/GDPR, stability of private APIs, anti-bot measures, cost.

## Existing work

Open-source clients, wrappers, MCP servers, apps doing the same.

## Sources

- <link> — what it supports
