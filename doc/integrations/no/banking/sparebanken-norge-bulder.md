---
id: no-sparebanken-norge-bulder
name: Sparebanken Norge / Bulder Bank (PSD2)
scope: no
category: banking
operator: Sparebanken Norge (formerly Sparebanken Vest); Bulder Bank is its digital brand
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

# Sparebanken Norge / Bulder Bank

Bulder Bank has no separate developer portal; one source says Sparebanken Norge and Bulder Bank offer PSD2 APIs built on Berlin Group NextGenPSD2.

## Access

- **api-public** (regulated) — Bits lists `https://developer.spvapi.no` for Sparebanken Norge (the Bulder link is not listed). TPP status required for live data.

## Data

Standard AIS: accounts, balances, transactions. No line items.

## FoodSavr mapping

Merchant-level hints only.

## Risks and constraints

Bulder coverage via this portal is unverified; third-party tracker pages on Bulder conflict.

## Existing work

None.

## Sources

- https://www.bits.no/?p=2161 — portal list
- https://openbankingtracker.com/provider/bulder-bank — tracker (low reliability)
