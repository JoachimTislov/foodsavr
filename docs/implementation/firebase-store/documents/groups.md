# Groups Collection

The `groups` collection manages collaborative groups, their members, and shared items.

## Collection Path

`/groups/{groupId}`

## Structure

```
/groups/{groupId}
  - name: "The Foodies"
  - ownerId: "{userId}"
```

## Subcollections

The `groups` collection contains several subcollections for managing group-related data:

*   **Members:** A list of users who are part of the group.
*   **Shared Inventory:** An inventory of products shared among group members.
*   **Shared Shopping Lists:** Shopping lists that are shared and can be edited by all group members.

### Members Subcollection

`/groups/{groupId}/members/{userId}`

```
/members/{userId}
  - role: "leader" | "member"
```

### Shared Inventory Subcollection

`/groups/{groupId}/sharedInventory/{inventoryId}`

```
/sharedInventory/{inventoryId}
  - productRef: /globalProducts/{productId}
  - quantity: 5
```

### Shared Shopping Lists Subcollection

`/groups/{groupId}/sharedShoppingLists/{listId}`

```
/sharedShoppingLists/{listId}
  - name: "Group Shopping"
```
