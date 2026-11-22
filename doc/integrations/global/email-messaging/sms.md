---
id: global-sms
name: SMS gateway
scope: global
category: email-messaging
operator: Twilio / Vonage / others
access: [api-public]
auth: api-key
data: [lists]
item_level: false
cost: paid
user_base: universal
tos_risk: low
fit: 1
status: researched
last_verified: 2026-11-21
---

# SMS gateway

Inbound SMS to a FoodSavr number could add list items. Costly and low value versus Telegram/WhatsApp.

## Access

- **api-public** — Twilio Programmable Messaging webhooks; per-message pricing (unverified).

## Data

Plain text.

## FoodSavr mapping

`lists` via text only.

## Risks and constraints

- Number rental and per-message cost; regulatory registration.

## Existing work

- Generic.

## Sources

- https://www.twilio.com/docs/messaging — Twilio Messaging
