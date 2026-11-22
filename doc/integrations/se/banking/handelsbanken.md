---
id: se-handelsbanken
name: Handelsbanken Developer Portal (PSD2)
scope: se
category: banking
operator: Svenska Handelsbanken AB
access: [api-public]
auth: oauth2
data: [purchases]
item_level: false
cost: free
user_base: Large Swedish bank
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# Handelsbanken Developer Portal (PSD2)

PSD2 APIs for Sweden, Great Britain, Finland, the Netherlands and Luxembourg at developer.handelsbanken.com. The portal covers the sandbox only; Live is separate.

## Access

- **api-public (regulated)** — accounts, payments, funds confirmation. Onboarding needs a qualified eIDAS certificate (QWAC) or UK Open Banking certificate (OBWAC). Swedish payment endpoints moved to a `/se/v2` path; Accounts and Subscriptions were not part of that migration. The customer needs a valid KYC relationship to retrieve accounts.

## Data

Accounts and transactions with merchant text; no item data.

## FoodSavr mapping

Merchant-level signal only.

## Risks and constraints

Certificates and TPP status required; aggregator route is simpler.

## Existing work

None reviewed.

## Sources

- https://developer.handelsbanken.com/psd2 — portal scope
- https://developer.handelsbanken.com/api/psd2/live — Swedish changes
- https://developer.handelsbanken.com/api/changelog — change log
