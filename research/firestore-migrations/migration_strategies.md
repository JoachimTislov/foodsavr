# Migration Strategies

There is no single "right" way to migrate data in Firestore. The best approach depends on the scale of your app, the type of change, and your risk tolerance.

### 1. Lazy (Client-Side) Migration - *Recommended for Mobile*
The app migrates data "just-in-time" as it is read.
*   **How it works:** When the app reads a document, it checks the `schemaVersion`. If the version is outdated, the app transforms the data in memory to the new format. It then optionally writes the updated version back to Firestore immediately.
*   **Pros:** Zero downtime; no expensive batch scripts; only "active" data is migrated (saving read/write costs).
*   **Cons:** Migration logic must remain in the codebase indefinitely to support infrequent users who haven't opened the app in a long time.

### 2. In-Place Batch (Server-Side) Migration
Use a background script (Cloud Functions or a local Node/Dart script using Firebase Admin) to update all documents at once.
*   **How it works:** Query for all documents with `schemaVersion < current`, iterate, and update them via Batched Writes (up to 500 per batch).
*   **Pros:** Cleans up the entire database consistently; allows you to eventually delete legacy migration code from the client app.
*   **Cons:** Can be expensive due to the high volume of reads and writes. Risk of "hotspotting" if updating millions of docs too fast. Needs coordination with app releases.

### 3. The "Expand and Contract" Pattern (Parallel Change)
The gold standard for zero-downtime breaking changes (e.g., renaming a field or moving data).
1.  **Expand:** Add the new field. Update the app to **write to both** the old and new fields, but still **read from the old** one.
2.  **Migrate:** Run a background script to copy data from the old field to the new field for all existing documents.
3.  **Contract:** Update the app to **read and write only to the new** field. Once all users have updated (or a grace period passes), delete the old field from your schema entirely.

### 4. Versioned Collections / Endpoints
If making a massive architectural shift, write to a new collection entirely (e.g., `users_v2`). Alternatively, if using Cloud Functions as an API layer, version the API (`/v1/getUser` vs `/v2/getUser`) and let the server handle the mapping.