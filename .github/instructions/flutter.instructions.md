---
applyTo: "lib/**,test/**"
---

# Flutter and Dart

- Keep views and widgets thin. Business logic belongs in models or services;
  repository access goes through interfaces and GetIt.
- Retrieve dependencies with `getIt<T>()`; do not construct repositories or
  services in widgets.
- Keep one widget per file and do not add private view builders or business
  logic to `build`.
- Use `easy_localization` keys from `assets/translations/`. Run
  `make locale-check` after localization changes and use `make locale-clean`
  only for confirmed unused keys.
- Run `make check` before committing Dart changes.
