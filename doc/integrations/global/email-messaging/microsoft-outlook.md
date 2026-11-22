---
id: global-microsoft-outlook
name: Microsoft Graph Outlook Mail
scope: global
category: email-messaging
operator: Microsoft
access: [api-public]
auth: oauth2
data: [purchases, line-items, orders]
item_level: true
cost: free
user_base: hundreds of millions of Outlook/Microsoft 365 mailboxes
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# Microsoft Graph Outlook Mail

Same pattern as Gmail for Outlook.com and Microsoft 365 mailboxes through Graph.

## Access

- **api-public** — Graph `/me/messages` with `Mail.Read`; OAuth2; supports server-side filtering and webhooks (change notifications).

## Data

Messages with HTML body and attachments; parse like Gmail.

## FoodSavr mapping

`purchases`/`orders` from parsed receipt emails.

## Risks and constraints

- Work tenants may require admin consent.
- Template changes break parsers.

## Existing work

- Official SDKs.

## Sources

- https://learn.microsoft.com/en-us/graph/api/resources/mail-api-overview — Graph mail API
