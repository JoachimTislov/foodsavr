---
id: no-sparebank-1
name: SpareBank 1 (PSD2, per-bank portals)
scope: no
category: banking
operator: SpareBank 1 Alliance banks (SMN, SR-Bank, Nord-Norge, Østlandet, Østfold Akershus, etc.)
access: [api-public]
auth: oauth2
data: [purchases]
item_level: false
cost: unknown
user_base: Second-largest Norwegian bank alliance (size unverified)
tos_risk: low
fit: 3
status: researched
last_verified: 2026-11-21
---

# SpareBank 1

Each SpareBank 1 bank runs its own PSD2 portal on a shared platform (Berlin Group NextGenPSD2). Enrolling with one bank reportedly grants access to the others in the shared list, per Bits.

## Access

- **api-public** (regulated) — portals such as `psd2.soa.sparebank1.no` (Østfold Akershus), `psd2.smn.no`, `psd2.sr-bank.no`, `psd2.snn.no`, `psd2.sb1ostlandet.no`. Sandbox: `https://psd2.soa.sparebank1.no/api-sandbox`, starts empty and is seeded via the Mock Data Common API. OAuth 2.0 simplified/mocked in sandbox. The Account Information API requires being a registered AISP for live use.
- Aggregator route is simpler for a consumer app.

## Data

Berlin Group AIS: accounts, balances, transactions (merchant-level). No line items.

## FoodSavr mapping

Same as `dnb.md`: merchant-level grocery spend hints only.

## Risks and constraints

AISP registration or aggregator dependency; consent renewal; one enrolment covering many banks must be verified.

## Existing work

None specific to FoodSavr.

## Sources

- https://www.bits.no/?p=2161 — portal list and shared enrolment
- https://psd2.soa.sparebank1.no/developer/getting-started — getting started
- https://psd2.soa.sparebank1.no/developer/docs/documentation — documentation
