# Less food wasted. Less effort managing it.

FoodSavr helps you know what food you have, what needs using, and what you
need to buy, so you can reduce food waste, save time, and manage grocery
expenses.
{ .vision-intro }

[Explore the specification](specs/source-of-truth/INDEX.md){ .md-button .md-button--primary }
[Start contributing](doc/getting_started.md){ .md-button }

## The problem we want to solve

Managing food means piecing together receipts, cupboards, expiry dates,
recipes, and shopping lists. When that picture is incomplete, it's easy to
forget food you already have, buy duplicates, and let ingredients expire.
Keeping an inventory by hand adds another chore.

FoodSavr's goal is to connect these pieces with as little manual work as
possible: turn everyday food inputs into useful inventory information and,
eventually, a grocery list that reflects what you actually need.

<div class="grid cards" markdown>

- **Know what you have**

    See your food inventory across collections and spot items expiring soon.

- **Make adding food easier**

    Use barcodes, receipts, and supported purchase-history integrations to
    reduce manual entry.

- **Connect purchases to plans**

    The vision brings inventory, recipes, and meal plans together to help
    generate grocery lists with zero to one user interactions.

</div>

## From food inputs to a useful grocery list

The [target architecture](specs/source-of-truth/architecture.md) treats
FoodSavr as an adapter: normalize food information from different sources
into a shared **LineItem**, then reuse that information across the app.

The planned ingestion pipeline covers receipts, loyalty APIs, orders,
recipes, barcodes, and free text. It combines normalization, matching,
shelf-life inference, and confidence-based confirmation so uncertain inputs
can be checked. A thin in-app agent and a remote MCP server are planned to
reuse the same core logic.

## What works today, and what comes next

FoodSavr is a work in progress. The
[implementation status](specs/source-of-truth/status.md) is the source for
what is built and what remains planned.

| Available in the current code | Planned or not yet connected |
| --- | --- |
| Product inventory, collections, and transfers | Unified ingestion through the shared pipeline |
| Barcode lookup and Open Food Facts enrichment | More loyalty integrations and input sources |
| Receipt ingestion and OCR expiry scanning | Confidence-based confirmation UI |
| Rema purchase-history integration | Inventory-driven shopping lists and meal planning |
| Shared Dart core skeleton | Remote MCP tools and shared agent orchestration |

These capabilities describe the codebase; platform support varies. This
site publishes documentation, not a hosted version of the app.

## Read the spec, then explore the implementation

The [canonical specification](specs/source-of-truth/INDEX.md) explains the
system's architecture, data model, ingestion contracts, and boundaries.
It takes precedence over older planning and implementation guides.

The specification links directly to authoritative
[schemas](specs/source-of-truth/schemas/line-item.schema.json), the
[service registry](specs/source-of-truth/registries/services.yaml), and the
[MCP contract](specs/source-of-truth/contracts/mcp-tools.yaml). Those files
remain the source for their structures.

For development, use the [setup guide](doc/getting_started.md),
[test strategy](doc/test-strategy.md), and
[contribution guidelines](CONTRIBUTING.md). Older research and planning
material remains available through the [documentation overview](doc/introduction.md)
and search; planned ideas there aren't claims of shipped behavior.
