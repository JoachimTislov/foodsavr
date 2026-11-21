---
name: localization
description: Add, change, or audit FoodSavr translations with easy_localization. Use when touching user-facing strings, `assets/translations/`, pluralization, or named arguments.
metadata:
  audience: agent
  paths: "assets/translations/**"
---

# Localization

- Translations live in `assets/translations/` (`en.json`, `nb.json`). Every key exists in every locale, with a real translation.
- Keys are nested by feature and follow the existing naming in the files (for example `product.barcodeAssumedExpiry`).
- In code, use `.tr()`; pass parameters as `namedArgs`; use `.trWith(namedArgs: ..., when: ...)` from `lib/utils/localization.dart` when a message is omitted for missing data. Replace string concatenation with a parameterized key.
- Plurals use `plural()` with `zero`/`one`/`other` keys.

## Workflow

1. Find used keys: `scripts/locale/find_untranslated_keys.sh`.
2. Add keys to all locales at once: `scripts/locale/add_locale_key.sh "key1" "val1" "key2" "val2"`.
3. Generate stubs for missing keys: `make generate-locales`; remove unused keys: `make locale-clean`.
4. Done when `make locale-check` passes (every used key present in every locale, no unused keys).
