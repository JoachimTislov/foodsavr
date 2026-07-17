# Core Principles for Backward Compatibility in Firestore

Because Firestore is **schemaless-on-write** but **schema-dependent-on-read** (your app code expects a certain shape), you must actively design for data evolution. The primary goals are:
1. **Old App Versions** must not crash when they encounter new data fields.
2. **New App Versions** must gracefully handle documents lacking new fields.

### Key Practices

1. **Prefer Additive Changes:** 
   Always add new fields rather than renaming or deleting existing ones. Old clients will simply ignore fields they don't recognize, preventing crashes.

2. **Default Values in Models:**
   Ensure your data models (e.g., Dart classes) provide default values for missing fields. This allows a new app version to read an "old" document that lacks a newly added field without throwing a null reference exception.

3. **Schema Versioning:**
   Include a `schemaVersion` (integer) field in every document.
   *   **v1:** `{ "name": "John Doe", "schemaVersion": 1 }`
   *   **v2:** `{ "firstName": "John", "lastName": "Doe", "schemaVersion": 2 }`
   This explicitly tells the client code how to parse the document.

4. **Graceful Degradation:**
   Always handle `null` safely. Never force unwrap (`!`) data coming from Firestore unless you absolutely guarantee its existence through security rules and migrations.