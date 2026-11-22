---
id: nordic-storebox
name: Storebox
scope: nordic
category: receipts
operator: Storebox (Nexi Group, formerly Nets)
access: [api-partner, export]
auth: unknown
data: [purchases, line-items]
item_level: true
cost: partner
user_base: Consumer receipt app used with Nordic retailers (exact size unknown)
tos_risk: low
fit: 5
status: researched
last_verified: 2026-11-21
---

# Storebox

Digital receipt platform: retailers push POS receipts to Storebox, linked to the consumer's registered payment card, and the Storebox app shows them. It would give FoodSavr item-level purchases across chains without per-chain integrations. This entry supersedes the Storebox facts in [doc/research/storebox_integration.md](../../../research/storebox_integration.md), whose endpoint list and JSON example are not backed by the public docs (see Data).

## Access

- **api-partner** — Developer portal is now `dev-engage.nexigroup.com` (Nexi Engage API). Documented APIs: POS API, Loyalty API, User API, Receipt Data API (v1), PCI DSS Vault API. Credentials are issued only after a commercial agreement with Storebox. The Receipt Data API is REST, aimed at trusted third parties such as payment service providers, returns a receipt (including a rendered representation) by external id, and requires a Base64 HMAC signature header. ([Receipt Data API](https://dev-engage.nexigroup.com/receipt-data-api.html), [getting started](https://dev-engage.nexigroup.com/getting-started/storebox-receipts.html), [API Tracker](https://apitracker.io/a/storebox/developers))
- **export** — The consumer app lets users view, search and download receipts ([App Store](https://apps.apple.com/dk/app/storebox/id688349260)). Forwarding or sharing PDFs into FoodSavr is a fallback. A GDPR data export was not verified (unverified).
- No MCP server and no GitHub client for Storebox found. The `madsbuch/storebox-api` wrapper named in the old note could not be re-verified.

## Data

The POS API ingests ARTS POSLog 6.0 receipts and detects duplicates by checksum ([POS API](https://dev-engage.nexigroup.com/pos-api.html)), so receipts are probably line-item level. The Receipt Data API response schema was not readable: field names, EAN presence and history depth are unknown. Treat the JSON in the older note as illustrative only.

## FoodSavr mapping

Receipt -> purchase; lines -> `LineItem` (name, quantity, price). Lines are chain POS text, so product matching/normalisation is needed. No expiry data.

## Risks and constraints

- The partner agreement is the gate. The audience is PSPs and banks; whether a consumer-consent flow for third-party apps exists is unknown (unverified).
- Receipts reveal location and habits: GDPR consent and data minimisation.
- Participating chains differ per country; check coverage per market.

## Existing work

None found publicly. Related rails: Vipps/MobilePay (see `nordic/receipts/vipps-mobilepay.md`).

## Sources

- https://dev-engage.nexigroup.com/ — Nexi Engage developer portal (Storebox APIs)
- https://dev-engage.nexigroup.com/receipt-data-api.html — Receipt Data API
- https://dev-engage.nexigroup.com/pos-api.html — POS API (ARTS POSLog 6.0)
- https://apitracker.io/a/storebox/developers — API directory entry
- https://apps.apple.com/dk/app/storebox/id688349260 — consumer app
