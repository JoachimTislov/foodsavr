# Shopping Lists Subcollection

The `shoppingLists` subcollection is nested under each user's document and manages their shopping lists.

## Collection Path

`/users/{userId}/shoppingLists/{listId}`

## Structure

```
/shoppingLists/{listId}
  - name: "Weekly Groceries"
  - created: Timestamp
```

### Items Subcollection

Each shopping list has an `items` subcollection that contains the products on the list.

#### Collection Path

`/users/{userId}/shoppingLists/{listId}/items/{itemId}`

#### Structure

```
/items/{itemId}
  - productName: "Milk" // Denormalized for easy display
  - productRef: /globalProducts/{productId}
  - quantity: 1
  - isPurchased: false
```
