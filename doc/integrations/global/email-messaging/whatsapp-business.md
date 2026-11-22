---
id: global-whatsapp-business
name: WhatsApp Business Platform
scope: global
category: email-messaging
operator: Meta
access: [api-partner]
auth: oauth2
data: [lists, purchases]
item_level: false
cost: paid
user_base: 2B+ users (vendor claim, unverified)
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# WhatsApp Business Platform

Same use case as a Telegram bot but on WhatsApp. Cloud API requires a Meta business account and charges per conversation/template message.

## Access

- **api-partner** — WhatsApp Business Cloud API (Meta); webhooks for inbound messages; pricing per message category (details unverified).

## Data

Text, images, documents, location.

## FoodSavr mapping

Messages to `lists`/receipt OCR.

## Risks and constraints

- Business verification; per-message cost; template approvals; policy limits.

## Existing work

- BSPs such as Twilio resell access.

## Sources

- https://developers.facebook.com/docs/whatsapp/cloud-api — Cloud API docs
