---
id: se-ica
name: ICA (app, Stammis, shopping lists)
scope: se
category: grocery-retail
operator: ICA Gruppen AB
access: [api-private, mcp, export]
auth: oidc
data: [purchases, offers, lists, products, recipes]
item_level: false
cost: free
user_base: Sweden's largest grocery chain; ICA app and Stammis loyalty (exact size unverified)
tos_risk: high
fit: 4
status: researched
last_verified: 2026-11-21
---

# ICA (app, Stammis, shopping lists)

ICA is Sweden's largest grocery retailer. The ICA app holds shopping lists, favourite stores, weekly offers, Stammis bonus balance, saved recipes and barcode lookup. There is no official public API. Item-level purchase data most likely comes through digital receipts in Kivra (see `se-kivra`); the private app API gives purchase totals only.

## Access

- **api-private** — the app backend. Current stack per a 2026 MCP server: OIDC/PKCE against `ims.icagruppen.se` (Curity), data API at `apimgw-pub.ica.se`, login with personnummer+password, or BankID. The older `handla.api.ica.se` API documented in `svendahlstrand/ica-api` stopped working after ICA's changes on 2024-04-17. The gateway returns HTTP 451 to non-Swedish IPs. Access tokens live about 15 minutes.
- **mcp** — community servers: `kanylbullen/ica-mcp` (lists, recipes, offers, bonus, EAN lookup; MIT; password login only) and `jonasthim/ica-mcp` "ica-hub" (BankID login, OAuth for Claude, lists read/write, offers, bonus, products, purchase months/receipts, Handla prices; MIT).
- **export** — digital receipts delivered to Kivra for Stammis members (see `se-kivra`).

## Data

- Shopping lists with items and categories (free text), favourite stores, per-store offers, bonus balance, saved/random recipes, product by EAN/GTIN.
- Purchase history via ica-hub: months, and per purchase date, store, total, discount. No line items. Only available for roughly 30 minutes to a few hours after a fresh web BankID login.

## FoodSavr mapping

- Shopping lists: two-way sync with FoodSavr lists (free-text items, no EAN).
- Offers per favourite store: offers input class.
- Recipes: ingredients to recipes/lists.
- Purchases: totals only here; line items require the Kivra receipt route.

## Risks and constraints

- Private, undocumented API; ICA's app terms forbid reverse engineering (per ica-hub README). Both MCP projects state personal, non-commercial use only and breakage risk.
- Swedish egress IP required (HTTP 451 otherwise); BankID-only accounts do not work with password login.
- Storing personnummer/password or session tokens on behalf of users is a heavy GDPR and security burden.

## Existing work

- https://github.com/kanylbullen/ica-mcp
- https://github.com/jonasthim/ica-mcp
- https://github.com/svendahlstrand/ica-api (outdated documentation)
- https://github.com/khessman/matmetrics (ICA receipts via Kivra)

## Sources

- https://github.com/svendahlstrand/ica-api — outdated notice 2024-04-17
- https://github.com/kanylbullen/ica-mcp — endpoints, auth flow, 451 on non-SE IPs, tool list
- https://github.com/jonasthim/ica-mcp — BankID, purchase history limits, ToS note
- https://github.com/khessman/matmetrics — ICA receipts via Kivra OAuth2/PKCE
- https://icagruppen.se/arkiv/pressmeddelandearkiv/2019/ica-infor-digitala-kvitton-tillsammans-med-kivra — ICA and Kivra digital receipts
