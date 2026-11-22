---
id: de-picnic-de
name: Picnic Deutschland
scope: de
category: online-grocery
operator: Picnic
access: [api-private]
auth: username-password
data: [orders, products]
item_level: true
cost: free
user_base: Growing in NRW and other German regions
tos_risk: medium
fit: 4
status: researched
last_verified: 2026-11-21
---

# Picnic Deutschland

Picnic's German operation uses the same app/API as NL with country code DE. See `nl/online-grocery/picnic.md` for client details.

## Access

- **api-private** — same API as Dutch Picnic; set country code DE (python-picnic-api2, picnic-api npm).

## Data

Same as NL entry.

## FoodSavr mapping

Orders and deliveries to purchases/`LineItem`.

## Risks and constraints

Private APIs are undocumented, can change or be blocked without notice, and using them may breach the operator's terms of service. Credentials of the user would be handled by FoodSavr. Purchase data is personal data under GDPR.

## Existing work

`python-picnic-api2`, `picnic-api` (npm), WWW::Picnic (Perl).

## Sources

- https://pypi.org/project/python-picnic-api2/ — Python client
- https://npmjs.com/package/picnic-api — Node client
- https://web.do.metacpan.org/dist/WWW-Picnic/view/README.md — Perl client with DE setting
