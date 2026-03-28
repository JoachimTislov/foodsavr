# Product Registry & Collection Items Architecture - Implementation Plan

## Objective
Split the overloaded `Product` model into a **Registry Product** (Metadata) and **Collection Items** (Inventory/Shopping instances) to ensure strict data separation and a single source of truth.

## Technical Breakdown

### 1. Model Definitions (`lib/models/`)

#### `Product` (Registry)
```dart
class Product {
  final int id;
  final String name;
  final String description;
  final String? category;
  final String? imageUrl;
  final String? barcode;
  final String? userId; // Null for global
  final bool isGlobal;
  final List<String> tags;
  // NO quantity, NO expiries here.
}
```

#### `InventoryItem`
```dart
class InventoryItem {
  final String id;
  final int productId; // Reference to Registry
  final List<ExpiryEntry> expiries;
  // Computed property: quantity (sum of expiries)
}
```

#### `ShoppingListItem`
```dart
class ShoppingListItem {
  final String id;
  final int productId; // Reference to Registry
  final int count;
}
```

### 2. Data Layer Updates

#### `ICollectionRepository`
- Add `Future<List<InventoryItem>> getInventoryItems(String collectionId)`
- Add `Future<List<ShoppingListItem>> getShoppingItems(String collectionId)`
- Add `Future<void> addInventoryItem(String collectionId, InventoryItem item)`
- Add `Future<void> addShoppingItem(String collectionId, ShoppingListItem item)`

#### `CollectionRepository` (Firestore)
- Use sub-collections: `collections/{collId}/inventory_items` and `collections/{collId}/shopping_items`.

### 3. Service Layer Updates

#### `CollectionService`
- Orchestrate fetching both the Item and its associated `Product` metadata.
- Example: `getCollectionWithProducts(String id)` will return a wrapper containing items enriched with registry data.

---

## Phased Implementation Steps

### Phase 1: Foundation (Models & Interfaces)
1.  **Modify `Product` Model**: Strip quantity/expiries from `lib/models/product_model.dart`.
2.  **Add `InventoryItem` and `ShoppingListItem`** to the same file or new files.
3.  **Update `Collection` Model**: Remove `productIds` list.
4.  **Update Interfaces**: Add new methods to `ICollectionRepository`.

### Phase 2: Data Implementation (Repositories)
1.  **Update `CollectionRepository`**: Implement sub-collection logic.
2.  **Migration Script**: Create a temporary tool to migrate old `productIds` to new item instances (defaulting shopping list items to count 1 and inventory items to current expiries).

### Phase 3: Service Refactoring
1.  **Update `ProductService`**: Remove logic that handles instance quantity.
2.  **Update `CollectionService`**: Implement the new item management logic.

### Phase 4: UI Migration
1.  **Dashboard**: Update "Expiring Soon" to fetch from `InventoryItem`s.
2.  **Collection Detail**: Update to render either `InventoryItem` or `ShoppingListItem` rows.
3.  **Product Form**: Split into "Edit Registry Info" and "Add to Collection" (with quantity/expiry prompt).

## Verification
- `make check` (Expect many initial failures, resolved incrementally).
- Unit tests for new JSON parsing.
- Integration test for Shopping List -> Inventory conversion.
