---
id: global-gmail
name: Gmail API
scope: global
category: email-messaging
operator: Google
access: [api-public]
auth: oauth2
data: [purchases, line-items, orders]
item_level: true
cost: free
user_base: over a billion Gmail users
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# Gmail API

Read-only access to a user's mailbox lets FoodSavr parse order confirmations and e-receipts from grocers and delivery services. Item-level data depends on each sender's email template.

## Access

- **api-public** — Gmail API v1, OAuth2; `gmail.readonly` is a restricted scope requiring Google verification and a security assessment (CASA) for production apps (unverified current details).

## Data

Raw MIME messages; parse HTML/PDF attachments. Quantity, product name and price present in many retailer e-receipts; rarely EAN.

## FoodSavr mapping

`purchases`/`orders` with `LineItem` from parsed emails; parser per sender template or LLM extraction. Search filters (sender, label) limit scope.

## Risks and constraints

- Restricted-scope verification cost and time; privacy concerns about full-mailbox access.
- Template changes break parsers.

## Existing work

- Receipt-parsing startups use this pattern (unverified).

## Sources

- https://developers.google.com/gmail/api — Gmail API
- https://developers.google.com/gmail/api/auth/scopes — scopes
