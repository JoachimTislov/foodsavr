---
id: gb-ocado
name: Ocado
scope: gb
category: online-grocery
operator: Ocado Retail Ltd
access: [mcp, api-private, bot]
auth: username-password
data: [orders, prices]
item_level: true
cost: free
user_base: ~1M active customers (unverified); UK
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# Ocado

UK online-only grocer (Ocado Retail, Marks & Spencer partnership for food). Order history is item-level.

## Access

- **mcp/api-private** — `abracadabra50/uk-grocery-cli` lists Ocado as supported (London and South England); retailer provides no developer API.
- **bot** — site automation.

## Data

Order history with items and prices (unverified).

## FoodSavr mapping

Online orders map directly to purchases with line items.

## Risks and constraints

Unofficial community tooling for UK supermarkets exists; none of the major retailers publishes a developer API. Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR.

## Existing work

`uk-grocery-cli`.

## Sources

- https://awesome.ecosyste.ms/projects/github.com%2Fabracadabra50%2Fuk-grocery-cli — project listing
