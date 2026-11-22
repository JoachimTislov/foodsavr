---
id: global-imap-generic
name: Generic IMAP
scope: global
category: email-messaging
operator: IETF standard (provider-run)
access: [api-public]
auth: username-password
data: [purchases, line-items, orders]
item_level: true
cost: free
user_base: any mail provider
tos_risk: medium
fit: 3
status: researched
last_verified: 2026-11-21
---

# Generic IMAP

IMAP fallback for users whose mail provider lacks a modern API (Fastmail, iCloud, GMX, Proton Bridge, Nordic ISPs).

## Access

- **api-public** — IMAP (RFC 9051) with app password or OAuth2 (XOAUTH2) depending on provider; Dart packages such as `enough_mail` (unverified).

## Data

Raw mail; same parsing as other mail sources.

## FoodSavr mapping

`purchases`/`orders` from parsed receipts.

## Risks and constraints

- Storing app passwords is sensitive; many providers require app-specific passwords; IMAP from a mobile app may be heavy.

## Existing work

- `enough_mail` Dart IMAP client (unverified).

## Sources

- https://datatracker.ietf.org/doc/html/rfc9051 — IMAP4rev2
