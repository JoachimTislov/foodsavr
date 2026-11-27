# MCP Server & foodsavr_core

## foodsavr_core (built, skeleton)

`packages/foodsavr_core/` — pure Dart, no Flutter/Firebase imports. Public surface (`foodsavr_core.dart`): LineItem, Normalizer, Matcher, ShelfLife, ConfidenceGate, Pipeline (#202). Both the app and the future MCP server depend on it; it must never depend on them.

The authoritative tool contract is [contracts/mcp-tools.yaml](contracts/mcp-tools.yaml).

## MCP server (spec-ahead, #171)

- Remote server exposing tools: `ingest_receipt`, `read_orders`, `generate_shopping_list`, so Claude, Codex, or any agent can drive FoodSavr.
- Transport: streamable HTTP. Auth: OAuth 2.1.
- Shares ingestion/normalization/list logic with the app exclusively through `foodsavr_core`.
- Companion Go API server (ConnectRPC) is future work in #171; not built.
