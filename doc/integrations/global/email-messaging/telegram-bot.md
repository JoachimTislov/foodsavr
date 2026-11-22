---
id: global-telegram-bot
name: Telegram Bot
scope: global
category: email-messaging
operator: Telegram
access: [api-public]
auth: api-key
data: [lists, purchases]
item_level: false
cost: free
user_base: 900M+ monthly users (vendor claim, unverified)
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Telegram Bot

A FoodSavr Telegram bot lets users send free text, photos of receipts or voice notes into the app and receive expiry reminders.

## Access

- **api-public** — Telegram Bot API (HTTPS, bot token, webhooks or long polling); free.

## Data

Text, photos, documents, voice, location. Free text.

## FoodSavr mapping

Message to `lists`/`inventory`; photos go to receipt OCR.

## Risks and constraints

- Telegram is not end-to-end encrypted for bot chats.

## Existing work

- Large bot library ecosystem.

## Sources

- https://core.telegram.org/bots/api — Bot API
