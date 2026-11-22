---
id: no-handelsbanken
name: Handelsbanken Norway (PSD2)
scope: no
category: banking
operator: Handelsbanken (Norwegian branch)
access: [api-public]
auth: oauth2
data: [purchases]
item_level: false
cost: unknown
user_base: unknown
tos_risk: low
fit: 2
status: researched
last_verified: 2026-11-21
---

# Handelsbanken Norway

Handelsbanken's own portal (developer.handelsbanken.com) documents Sweden, UK, NL and Luxembourg; for Norway, PSD2 is served through a separate portal.

## Access

- **api-public** (regulated) — Bits lists `https://openbanking.handelsbanken.no/portal-sandbox/gettingstarted`; Bits also notes that enrolling at a SpareBank 1 portal gives access to the shared list including Handelsbanken (see `sparebank-1.md`). The main Handelsbanken portal says live Account Information access needs a QWAC eIDAS certificate; a free developer account gives sandbox access there.

## Data

Accounts, balances, transactions. No line items.

## FoodSavr mapping

Merchant-level hints only.

## Risks and constraints

TPP certification or aggregator; small retail share in Norway (unverified).

## Existing work

None specific to FoodSavr.

## Sources

- https://www.bits.no/?p=2161 — Norwegian portal list
- https://developer.handelsbanken.com/psd2 — main portal (no Norway section)
- https://developer.handelsbanken.com/psd2/apis/accounts — Account Information API
