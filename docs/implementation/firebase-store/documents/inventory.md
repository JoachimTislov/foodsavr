# Inventory Subcollection

The `inventory` subcollection is nested under each user's document and tracks the products they currently have.

## Collection Path

`/users/{userId}/inventory/{inventoryId}`

## Structure

```
/inventory/{inventoryId}
  - productRef: /globalProducts/{productId}
  - quantity: 1
  - expirationDate: Timestamp
```
