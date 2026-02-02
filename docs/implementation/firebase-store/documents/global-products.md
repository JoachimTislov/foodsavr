# Global Products Collection

The `globalProducts` collection is a central repository for all products available in the application. This allows for a shared database of products that users can add to their inventory or shopping lists.

## Collection Path

`/globalProducts/{productId}`

## Structure

```
/globalProducts/{productId}
  - name: "Organic Milk"
  - barcode: "123456789"
  - price: 2.99
  - addedBy: "{userId}" // Reference to the user who added it
```
