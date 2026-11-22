---
id: no-dnb
name: DNB (PSD2 / open banking)
scope: no
category: banking
operator: DNB Bank ASA
access: [api-public]
auth: oauth2
data: [purchases]
item_level: false
cost: unknown
user_base: Norway's largest bank (size unverified)
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# DNB (PSD2)

DNB publishes PSD2 APIs for registered third-party providers. Account information gives merchant-level card transactions (no line items). The same portal is listed for Sbanken (see `sbanken.md`).

## Access

- **api-public** (regulated) — developer portal `https://developer.dnb.no/`; DNB's PSD2 page points developers there. Live account-information access needs TPP status: an AISP licence/registration and eIDAS certificate (general PSD2 rule; Norway-specific steps unverified). Sandbox for non-licensed developers: unverified.
- Easier route for FoodSavr: a licensed aggregator (Tink, Neonomics, Enable Banking, etc.; covered under `nordic/` or `eu/` if catalogued).

## Data

Accounts, balances, transactions (merchant name, amount, date, MCC where provided; unverified). No receipt lines. PSD2 limits unattended AIS calls to about four per account per day (RTS rule, per a third-party listing).

## FoodSavr mapping

Merchant-level purchases: detect grocery visits (Rema, Kiwi...) to prompt "add what you bought" or reconcile with chain-app data. No `LineItem`s.

## Risks and constraints

- Regulatory burden of becoming an AISP, or dependence on an aggregator (cost, GDPR processor terms).
- Consent re-authorisation every 90-180 days (PSD2 SCA rules; verify current).

## Existing work

None specific to FoodSavr.

## Sources

- https://www.dnb.no/en/corporate-and-institutions/psd2.html — PSD2 page
- https://www.bits.no/?p=2161 — list of Norwegian PSD2 developer portals
- https://jentic.com/apis/dnb — third-party listing (call limits)
