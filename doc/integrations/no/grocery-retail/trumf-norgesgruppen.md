---
id: no-trumf-norgesgruppen
name: Trumf (NorgesGruppen: Kiwi, Meny, Spar, Joker)
scope: no
category: grocery-retail
operator: Trumf / NorgesGruppen ASA
access: [api-private]
auth: username-password
data: [purchases, line-items, offers]
item_level: true
cost: free
user_base: Norway's largest grocery loyalty scheme (member count unverified)
tos_risk: high
fit: 5
status: researched
last_verified: 2026-11-21
---

# Trumf (NorgesGruppen)

Trumf is the shared bonus programme and app for NorgesGruppen chains: Kiwi, Meny, Spar, Joker, Nærbutikken, Jacobs, CC Mat. One account covers all chains, so a single entry is used; Kiwi (Kiwi PLUSS) and Spar have their own apps, but no separate APIs were found. The Trumf app offers digital receipts for partner stores covering the past 12 months (third-party listing) and Trumf Pay (since Aug 2024).

## Access

- **api-private** — reverse-engineered REST at `platform-rest-prod.ngdata.no/trumf/`. Auth: phone number + password exchanged for a bearer token (per gist and project plan; not OAuth). Endpoints: `husstand/transaksjoner` (list) and `.../detaljer/{batchid}` (line items). Thinly documented.
- No official public API found.

## Data

Household transactions and line-item details. The gist gives endpoints only; whether items carry EAN and quantities is unverified for Trumf.

## FoodSavr mapping

Purchases from Kiwi/Meny/Spar/Joker to `LineItem` once EAN/quantity presence is confirmed. Offers (Triple Trumf, Kiwi PLUSS) are not covered by known endpoints.

## Risks and constraints

- Requires storing the user's password rather than a refresh token; needs strong encryption or a user-side relay.
- Private API and ToS risk; can change without notice.
- Trumf Pay purchases may differ in receipt availability (unverified).

## Existing work

- Helge Sverre gist (Trumf section thin).
- No open-source client or MCP server found.

## Sources

- https://gist.github.com/HelgeSverre/80a7f34f874336324184a0c513c2e6a2
- https://sourceforge.net/app/trumf/iphone/ — app listing, digital receipts, partner chains (third party)
- https://esmmagazine.com/technology/norgesgruppen-introduces-mobile-payment-with-trumf-pay-272081
- doc/plan/grocery-private-api-integration.md
