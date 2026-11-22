---
id: eu-lidl-plus
name: Lidl Plus
scope: eu
category: receipts
operator: Schwarz Gruppe (Lidl)
access: [api-private, export, bot]
auth: oauth2-pkce
data: [purchases, line-items, offers]
item_level: true
cost: free
user_base: Lidl Plus app in ~30 countries, tens of millions of users
tos_risk: medium
fit: 5
status: researched
last_verified: 2026-11-21
---

# Lidl Plus

Lidl's loyalty app. It stores digital receipts (e-tickets) per purchase, with line items, for users who scan the Lidl Plus QR code at checkout. An unofficial Python client exists that fetches these receipts.

## Access

- **api-private** — mobile-app API behind the Lidl account login (accounts.lidl.com, ticket service on lidlplus.com hosts, unverified). The `lidl-plus` Python package takes language, country and a refresh token and iterates `tickets()`; the token is generated once through a Chrome-driven login. Newer clients (`ilidl`) note the API rejects fake app-version headers.
- **export** — GDPR data request to Lidl (unverified detail level).
- **bot** — browser automation of the login to obtain the refresh token (used by the clients above).

## Data

Receipt = store, timestamp, total, line items (name, quantity, price, VAT). EAN is not shown in the client docs found (unverified). Coupons and offers are also exposed by the clients. Per-country accounts (country code and language parameters).

## FoodSavr mapping

Receipts map to purchases and `LineItem` (name, quantity, unit price). Lack of EAN means matching by product name; no expiry. One integration covers every Lidl country (scope `eu`), so a single login flow gives broad coverage.

## Risks and constraints

Reverse-engineered; the package states it can stop working at any time. Login needs a browser step. Terms of service likely forbid automated access (unverified). Refresh token is a long-lived credential and must be stored encrypted.

## Existing work

`Andre0512/lidl-plus` (Python, receipts, coupons, CLI to JSON); `zsobix/lidlplus-api` (fork, Playwright login); `ilidl` (newer client, claims upstream broken on modern Python); `bluewalk/lidlplus-dotnet-client` (.NET); `FaserF/ha-lidl` (Home Assistant).

## Sources

- https://github.com/Andre0512/lidl-plus — unofficial Python client
- https://pypi.org/project/lidl-plus — package page
- https://pypi.org/project/ilidl/ — newer client
- https://github.com/bluewalk/lidlplus-dotnet-client — .NET client
- https://github.com/FaserF/ha-lidl/releases — Home Assistant integration
