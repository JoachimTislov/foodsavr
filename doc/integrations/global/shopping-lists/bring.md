---
id: global-bring
name: Bring! Shopping List
scope: global
category: shopping-lists
operator: Bring! Labs AG (Zurich)
access: [api-private, mcp]
auth: username-password
data: [lists]
item_level: true
cost: free
user_base: very popular in DACH and Nordics (exact size unverified)
tos_risk: medium
fit: 5
status: researched
last_verified: 2026-11-21
---

# Bring! Shopping List

Collaborative shopping list app with household-shared lists and a fixed item catalogue. FoodSavr could two-way sync its shopping list with Bring, or import what users already put on their lists.

## Access

- **api-private** — reverse-engineered REST API used by the Bring! apps (email + password login returns a bearer token; list UUIDs). No official public developer API found (absence unverified). Community clients: Node `bring-shopping` (foxriver76/node-bring-api), Python `bring-api`.
- **mcp** — several community MCP servers wrapping the same unofficial API (see Existing work).

## Data

Lists (UUID, name), items as `{name, specification}` (specification = free-text quantity/note), purchase vs recently-used sections, translated catalogue item keys with icons. No EAN/GTIN. Items carry no expiry.

## FoodSavr mapping

Maps to `lists` (two-way). Item `specification` holds quantity as free text and needs parsing into `LineItem` quantity/unit. No product identity beyond the name, so enrichment needs name matching. Not a purchase source: removing an item does not mean it was bought.

## Risks and constraints

- No official API; login needs the user's password or a stored token. Breakage without notice is likely.
- Terms of use not reviewed (unverified); unofficial access probably breaches them.
- The Node client states it is not affiliated with Bring! Labs AG.

## Existing work

- foxriver76/node-bring-api (TypeScript, npm `bring-shopping`)
- `bring-api` on PyPI (non-legacy API; Python)
- MCP: arithmetic-zz/bring-mcp-server, florianwittkamp/bring-mcp, mekanics/mcp-bring

## Sources

- https://github.com/foxriver76/node-bring-api — node client, non-affiliation notice
- https://pypi.org/project/bring-api — Python client
- https://github.com/arithmetic-zz/bring-mcp-server — MCP server
- https://mcpservers.org/servers/florianwittkamp/bring-mcp — MCP listing
- https://glama.ai/mcp/servers/mekanics/mcp-bring — MCP server using the reverse-engineered API
