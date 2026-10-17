---
applyTo: ".github/workflows/**,Makefile"
---

# CI and Make

- Keep workflow paths, commands, and prerequisites consistent with the
  existing Make targets, especially `make check` and `make rules-test`.
- Required checks must remain blocking; never weaken or bypass them.
- Path-filter new jobs so unrelated changes do not trigger expensive suites.
- Use Firebase emulators and harmless demo data only. Do not add credentials or
  production access.
