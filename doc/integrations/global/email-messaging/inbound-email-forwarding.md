---
id: global-inbound-email-forwarding
name: Email forwarding inbox (receipts@ address)
scope: global
category: email-messaging
operator: SendGrid / Mailgun / Postmark / AWS SES (provider choice open)
access: [api-public, export]
auth: api-key
data: [purchases, line-items, orders]
item_level: true
cost: freemium
user_base: n/a (FoodSavr-run)
tos_risk: low
fit: 4
status: researched
last_verified: 2026-11-21
---

# Email forwarding inbox (receipts@ address)

Users forward receipt emails to a FoodSavr address (per-user alias). An inbound-mail webhook delivers parsed content, avoiding mailbox OAuth and its verification cost.

## Access

- **api-public** — SendGrid Inbound Parse, Mailgun Routes, Postmark Inbound, SES receiving: all POST parsed email (headers, text, html, attachments) to a webhook. Firebase Cloud Function can receive.

## Data

Same as email receipts; attachments (PDF receipts) included.

## FoodSavr mapping

`purchases`/`orders` per forwarded mail; alias identifies the user; also supports auto-forward rules set by the user.

## Risks and constraints

- Spam and abuse handling; PII retention policy; DNS MX setup.

## Existing work

- Used by expense tools (Expensify, etc.; unverified).

## Sources

- https://www.twilio.com/docs/sendgrid/for-developers/parsing-email/setting-up-the-inbound-parse-webhook — SendGrid Inbound Parse
- https://documentation.mailgun.com/docs/mailgun/user-manual/receive-forward-store/receive-forward-store — Mailgun routes (verify path)
