---
id: no-sbanken
name: Sbanken (now DNB)
scope: no
category: banking
operator: DNB Bank ASA (Sbanken acquired by DNB; completion details unverified)
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

# Sbanken

Sbanken was historically known for a customer-facing open API (personal developer portal) and PSD2 APIs. Bits now lists one shared portal, "DNB and Sbanken", at developer.dnb.no, implying Sbanken's APIs sit under DNB. The acquisition by DNB is from general knowledge; not confirmed by a fetched source.

## Access

- **api-public** — `https://developer.dnb.no/`. Whether the legacy Sbanken personal-customer API (self-service access for own accounts) still exists is unverified; if so it would be a no-TPP route for users' own data.
- See `dnb.md` for PSD2 requirements.

## Data

Accounts, balances, transactions. No line items.

## FoodSavr mapping

Merchant-level hints only.

## Risks and constraints

Migration into DNB may have changed or removed Sbanken-specific APIs.

## Existing work

Community clients for the old Sbanken API exist (unverified).

## Sources

- https://www.bits.no/?p=2161 — "DNB and Sbanken" portal
- https://openbankingtracker.com/provider/sbanken/apis — tracker listing
- https://www.finextra.com/newsarticle/31545/sbanken-opens-developer-portal-and-invites-customers-to-build-their-own-digital-bank — original Sbanken developer portal
