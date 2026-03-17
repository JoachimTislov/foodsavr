# Cloud Firestore Security Rules for foodsavr

### Summary

This document defines the security rules for the `foodsavr` Cloud Firestore database. These rules are essential for protecting user data and ensuring that users can only perform actions they are authorized to. The rules follow a default-deny policy, meaning that access is denied unless a rule explicitly grants it. Security is enforced by checking user authentication status, user roles, and data ownership.

---

### Default Security Stance

By default, all reads and writes to the database are denied. This is the most secure posture, as it ensures no data is accessible or modifiable unless we explicitly allow it.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Deny all reads and writes by default.
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

### Rule Explanations

Here are the detailed rules for each collection.

#### 1. Users Collection

This rule governs access to the `users` collection, where private user information is stored.

**Rule:**
```
match /users/{userId} {
  // A user can only read or write their own document.
  // This is crucial for protecting personal information.
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```
**Explanation:**
*   `allow read, write`: This rule applies to both reading and writing data.
*   `if request.auth != null`: Ensures that the user is logged in.
*   `&& request.auth.uid == userId`: Ensures that the logged-in user's UID matches the ID of the document they are trying to access.

#### 2. User Subcollections

This is a general rule to protect all subcollections within a user's document, such as `inventory`, `shoppingLists`, `recipes`, `meals`, and `mealPlans`.

**Rule:**
```
match /users/{userId}/{anySubCollection}/{anyDoc=**} {
  // A user can only access the subcollections within their own document.
  // This protects all their personal data like inventory, recipes, etc.
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```
**Explanation:**
*   `{anySubCollection}/{anyDoc=**}`: This is a recursive wildcard that matches any document in any subcollection under a `users` document.
*   This rule enforces that only the owner of the user document can access any of the documents within its subcollections.

#### 3. Global Collections (`globalProducts`, `recipes`, `meals`)

These rules govern access to the global, shared data in the application.

**Rule:**
```
// This function checks if a user has the 'admin' role.
function isAdmin() {
  return request.auth != null &&
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}

match /globalProducts/{productId} {
  // Any logged-in user can read the global products.
  allow read: if request.auth != null;
  // Only admins can create, update, or delete global products.
  allow write: if isAdmin();
}

match /recipes/{recipeId} {
  // Any logged-in user can read the global recipes.
  allow read: if request.auth != null;
  // Only admins can write to the global recipes collection.
  allow write: if isAdmin();
}

match /meals/{mealId} {
  // Any logged-in user can read the global meals.
  allow read: if request.auth != null;
  // Only admins can write to the global meals collection.
  allow write: if isAdmin();
}
```
**Explanation:**
*   We define a helper function `isAdmin()` to avoid repeating the admin check logic. This function gets the user's document and checks if their `role` field is set to `'admin'`.
*   Any authenticated user is allowed to read from these collections.
*   Only users with the `'admin'` role are allowed to write (create, update, delete) to these collections. This prevents regular users from modifying the global data.

#### 4. Groups Collection

These rules manage access to collaborative groups and their shared data.

**Rule:**
```
// This function checks if a user is a member of a specific group.
function isGroupMember(groupId) {
  return request.auth != null &&
         exists(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid));
}

// This function checks if a user is the leader of a specific group.
function isGroupLeader(groupId) {
    return request.auth != null &&
           get(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid)).data.role == 'leader';
}


match /groups/{groupId} {
  // Only group members can read the group's main document.
  allow read: if isGroupMember(groupId);
  // Only the group leader can update the group's main document (e.g., change the name).
  allow write: if isGroupLeader(groupId);
}

match /groups/{groupId}/{subCollection}/{docId=**} {
    // Group members can read and write to the subcollections (e.g., shared shopping lists).
    allow read, write: if isGroupMember(groupId);
}
```
**Explanation:**
*   We define helper functions `isGroupMember()` and `isGroupLeader()` to check a user's status within a group.
*   `isGroupMember()` uses `exists()` to see if a document for the user exists in the `members` subcollection. This is a very efficient way to check for membership.
*   `isGroupLeader()` uses `get()` to retrieve the user's member document and check if their role is `'leader'`.
*   Only group members can read group data.
*   Only the group leader can modify the group's main document or manage members.
*   All group members are allowed to read and write to the shared subcollections (like a shared shopping list). You could make these rules more granular if needed (e.g., only leaders can delete items).

---

### Complete `firestore.rules` File

Here is the complete set of rules that you can use in your project.

```
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    // Helper Functions
    function isAdmin() {
      return request.auth != null &&
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    function isGroupMember(groupId) {
      return request.auth != null &&
             exists(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid));
    }

    function isGroupLeader(groupId) {
        return request.auth != null &&
               get(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid)).data.role == 'leader';
    }

    // Rule 1: Users Collection
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Rule 2: User Subcollections
    match /users/{userId}/{anySubCollection}/{anyDoc=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Rule 3: Global Collections
    match /globalProducts/{productId} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }

    match /recipes/{recipeId} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }

    match /meals/{mealId} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }

    // Rule 4: Groups Collection
    match /groups/{groupId} {
      allow read: if isGroupMember(groupId);
      allow write: if isGroupLeader(groupId);
    }

    match /groups/{groupId}/{subCollection}/{docId=**} {
        allow read, write: if isGroupMember(groupId);
    }
  }
}
```
