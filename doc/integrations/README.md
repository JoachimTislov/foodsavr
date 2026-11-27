# Integration catalog

Research catalog of external services FoodSavr could ingest from or act on. One file per integration. Research only: nothing here is built or committed to. Built and spec'd integrations live in [specs/integrations.md](../../specs/integrations.md) and [registries/services.yaml](../../specs/registries/services.yaml); this catalog never overrides them.

## Layout

```
doc/integrations/
  README.md          this standard + index
  _TEMPLATE.md       copy for every new entry
  <scope>/<category>/<service>.md
```

- `<scope>`: ISO 3166-1 alpha-2 country code in lower case (`no`, `se`, `dk`, `fi`, `de`, `gb`, `us`, …), `nordic` for services spanning several Nordic countries, `eu` for EU-wide services, `global` for services not tied to a country.
- `<category>`: one of the categories below. Add a new one only when no existing one fits.
- `<service>`: kebab-case service name (`rema-1000.md`, `open-food-facts.md`).

## Categories

| Category | What it covers | FoodSavr input class |
|---|---|---|
| `grocery-retail` | Physical grocery chains, their apps and loyalty programs | purchases, offers |
| `online-grocery` | Grocery e-commerce and delivery-of-groceries services | orders |
| `meal-kits` | Recipe box subscriptions | orders, recipes |
| `food-delivery` | Restaurant/takeaway delivery and order systems | orders |
| `receipts` | Digital receipt platforms and receipt email | purchases |
| `banking` | Banks and open-banking (PSD2) aggregators | purchases (merchant-level) |
| `product-data` | Product, barcode and nutrition databases | enrichment |
| `prices-offers` | Price comparison, flyers, discount data | offers |
| `recipes` | Recipe sites, recipe managers, recipe APIs | recipes |
| `meal-planning` | Meal planners and nutrition trackers | plans, consumption |
| `shopping-lists` | Shopping list and to-do apps | lists |
| `food-waste` | Surplus-food marketplaces and sharing | offers |
| `smart-home` | Smart fridges, appliances, voice assistants | inventory, lists |
| `email-messaging` | Mail and messaging channels used as a data source | purchases, free text |
| `ai-agents` | MCP servers and agent platforms | any |

## Access methods

Every entry classifies how FoodSavr can reach the service. List all that apply, best first.

| `access` value | Meaning |
|---|---|
| `api-public` | Documented API open to any developer (free or paid signup) |
| `api-partner` | Documented API behind a commercial or partner agreement |
| `api-private` | Undocumented API used by the service's own apps (reverse-engineered) |
| `mcp` | An MCP server exists (official or community) |
| `export` | User-driven export (CSV, GDPR data request, email forward, share sheet) |
| `feed` | Public data feed, dataset dump, RSS, iCal |
| `bot` | Only reachable by browser automation / scraping on the user's behalf |
| `none` | No viable access found |

## Entry standard

- Copy [_TEMPLATE.md](_TEMPLATE.md). Fill every frontmatter field; use `unknown` rather than guessing.
- Facts need a source link in `## Sources`. Mark unverified claims `(unverified)`.
- Never write credentials, API keys, client secrets or subscription keys into an entry, even when they are public elsewhere. Link the source instead.
- `last_verified` is the date the research was done. Re-verify before building.
- Keep entries short and factual. The owner picks what to build; entries do not recommend priorities beyond the `fit` score.

### `fit` score (1–5)

How much one integration would remove manual entry for FoodSavr users, weighed against access cost:

- 5 — item-level purchase/inventory data, viable access, large user base
- 4 — item-level data with notable access friction, or high-value enrichment
- 3 — useful but partial data (merchant-level, offers only, recipes)
- 2 — niche or hard to reach
- 1 — little value or no viable access

## Index

Each scope folder has a generated `README.md` listing its entries. After adding or editing entries run `scripts/docs/integration_index.py`; the docs group of `scripts/ci/local_ci.py` runs it with `--check`.

Scopes: [`ae`](ae/README.md), [`ar`](ar/README.md), [`au`](au/README.md), [`br`](br/README.md), [`ca`](ca/README.md), [`ch`](ch/README.md), [`co`](co/README.md), [`de`](de/README.md), [`dk`](dk/README.md), [`es`](es/README.md), [`eu`](eu/README.md), [`fi`](fi/README.md), [`fr`](fr/README.md), [`gb`](gb/README.md), [`global`](global/README.md), [`in`](in/README.md), [`is`](is/README.md), [`jp`](jp/README.md), [`nl`](nl/README.md), [`no`](no/README.md), [`nordic`](nordic/README.md), [`nz`](nz/README.md), [`pl`](pl/README.md), [`se`](se/README.md), [`sg`](sg/README.md), [`us`](us/README.md), [`za`](za/README.md).
