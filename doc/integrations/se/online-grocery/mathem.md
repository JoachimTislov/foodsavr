---
id: se-mathem
name: Mathem (incl. Mat.se)
scope: se
category: online-grocery
operator: Mathem i Sverige AB
access: [api-private, mcp, bot]
auth: username-password
data: [orders, products, prices, lists]
item_level: true
cost: free
user_base: Sweden's largest pure online grocer (Mathem's own claim); absorbed Axfood's Mat.se in the 2021 merger
tos_risk: high
fit: 4
status: researched
last_verified: 2026-11-21
---

# Mathem (incl. Mat.se)

Online grocery with home delivery. Mat.se (Axfood's online store) was merged into Mathem after approval by the Swedish Competition Authority, so no separate Mat.se integration exists (see `se-mat-se`). Orders would give item-level inventory input. No official API found.

## Access

- **api-private** — `Corpra/mathem-cli` (MIT): search without login, cart view/add/remove/clear with email+password. Order history and checkout are not mentioned.
- **mcp / agent** — `Malm/mathem-ai-agent-skill`, `sleipner42/mathem-mcp-server` (glama.ai listing; content not verified), `poisdahl/meal-concierge` (Oda, Mathem, MENY; not reviewed).
- **bot** — scraping used by `Colin-Andrew-Rasiga/matval` (ICA, Coop, Willys, Hemköp, Mathem products/prices/nutrition behind an MCP server).

## Data

Product search results and cart contents; nutrition shown by matval. Order history: not found.

## FoodSavr mapping

Cart push from shopping list; product enrichment. Orders to inventory only if order history can be read (unverified).

## Risks and constraints

Private API, password credentials stored locally, no official permission.

## Existing work

- https://github.com/Corpra/mathem-cli
- https://github.com/Malm/mathem-ai-agent-skill
- https://github.com/Colin-Andrew-Rasiga/matval
- https://github.com/pilotniq/veckohandling

## Sources

- https://raw.githubusercontent.com/Corpra/mathem-cli/HEAD/README.md — capabilities and auth
- https://esmmagazine.com/retail/swedens-mathem-completes-merger-with-mat-se-165957 — merger with Mat.se
- https://github.com/Colin-Andrew-Rasiga/matval — multi-chain scraping MCP
