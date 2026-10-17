---
applyTo: "firestore-rules/**,firestore.rules,firestore.indexes.json"
---

# Firestore

- Review every rules change as a security change. Preserve ownership checks on
  create, set, and update, and never allow client writes to the admin registry.
- Run `make rules-test`; it starts the Firebase emulators and runs the
  `firestore-rules/` Jest suite.
- Do not add production credentials. The repository intentionally supplies
  rules to CI through its existing secret mechanism.
