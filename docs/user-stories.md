# User stories

## Templates

- As a [role], I want [goal/functionality] so that [benefit]
- As a [type of user], I want to [perform some task] so that I can [achieve some goal].
- Given that [some context], when [some action is carried out], then [a set of observable outcomes should occur].

## Authentication and Login

- As a User, I want to sign up with my email and password so that I can create an account.
- As a User, I want to sign up with my Google, Facebook or Vipps account, so that I don't need to manage another password for a new account
- As a User, I want to log in with my credentials so that I can access my personal data.
- As a User, I want to change/update my password or delete my account so that I have control over my personal data.
- As a User, I want to receive a password reset link via email so that I can recover access if I forget my password.
- As a User, I want to enable two-factor authentication so that my account is more secure.
- As a User, I want my authentication token to be invalidated when I log out so that no one can reuse it after I’ve ended my session.
- As a User, I want to view the list of active sessions/devices so that I can revoke access if something looks suspicious.

## Products & Inventory

- As a User, I want to view my current inventory so that I know what I have.
- As a User, I want to receive a reminder before a product expires so that I don’t waste food.
- As a User, I want to search my inventory by product name, category, or expiration date so that I can quickly find items.
- As a User, I want to filter inventory by storage location (fridge, freezer, cabinet) so that I know where to look.
- As a User, I want to archive seasonal or rarely used products so that my active inventory stays clean.
- As a User, I want to add products to my personal inventory so that I can track my inventory.
- As a User, I want to scan a barcode, take pictures (not 100% accurate) or enter product details manually so that I can add products.
- As a User, I want to transfer products from the shopping list into my inventory once purchased so that the system stays up to date.

## Recipes

- As a User, I want to store and manage my recipes so that I can reuse them later.
- As a User, I want to categorize recipes (e.g., breakfast, dinner, vegetarian) so that they’re easier to find.
- As a User, I want to adjust serving sizes in recipes so that product amounts scale automatically.
- As a Group Member, I want to suggest edits to shared recipes so that collaboration is easier.

## Meals

- As a User, I want to store and manage my meals so that I can reuse them later.

## Meal Planning

- As a User, I want to create weekly or calendar-based meal plans so that I can stay organized.
- As a User, I want the meal plan to link with product expiration dates so that I minimize food waste.
- As a Group Member, I want to view shared products, recipes, meal plans and shopping list so that we can coordinate meals together.
- As a User, I want to drag-and-drop meals into my calendar so that I can plan meals more intuitively.
- As a User, I want to be alerted if the meals im planning isn't possible so that I can 
- As a User, I want previous meals to persist in the database so that I can view what I have eaten.
- As a Group Member, I want to coordinate meal plans with my family/group so that we avoid duplicate cooking.

## Shopping List

- As a User, I want a shopping list to be automatically generated from my meal plan so that I save time.
- As a User, I want to mark both items and the entire shopping list as bought/finished so that my inventory updates automatically.
- As a User, I want duplicate items in the shopping list to be merged so that the list is shorter and easier to read.

## Groups & Collaboration

- As a Group Leader, I want to enforce rules for editing shared products/recipes/meals so that group members won't be angry
- As a User, I want to create a group so that I can share meal plans and recipes with others.
- As a User, I want to invite others to my group via email so that they can easily join.
- As a User, I want to accept or decline group invitations so that I can choose who I collaborate with.
- As a User, I want to leave a group so that I am no longer tied to shared content I don’t want.
- As a Group Member, I want to add recipes made by other group members so that I can easily reuse them privately.
- As a Group Member, I want to synchronize my data ownership with the rest of the group with one click so that I don't lose data I forgot to add to my private storage.
- As a Group Member, I want to know who is the owner and the name of the group so that I know who am dealing with.
- Given that a group member leaves, when I view the group data, then only the data owned by the single user is not accesible by the remaining group members.

## Budget & Expenses

- As a User, I want to save shopping trips and their costs so that I can track spending over time.
- As a User, I want to see the cost per meal and product so that I can make budget-conscious choices.
- As a User, I want to view summary reports of expenses so that I can monitor my financial habits.
- As a User, I want to view discounts for products in my personal list, so that I can save money.

## Edge cases

(GOES UNDER VALIDATION) As a User, I want to be alerted when I try to add an existing item so that I don’t create duplicates.

## Technical

- As a Developer, I want users to be able to contribute products, recipes and meals to global repositories so that the community help each other save.
- As a Developer, I want to use gRPC for communication between services so that type-safety, modularity and scalability are ensured.
- As a Developer, I want logging of almost everything for debugging and safety so that issues can be traced more easily later on.
- Given a client submits invalid data, when it is inserted into the database, then the validation should prevent the insertion.
- As a Developer, I want tokens to have expiration time so that if a user forgets to log out, the token will eventually expire.
- As a Developer, I want users to democraticly add new products to the global list so that manual admin work is reduced.

## System

- As a SuperAdmin, I want to manage admins and system-wide settings so that governance is consistent.
- As an Admin, I want to manage users (view, ban?, delete) so that I can ensure the system stays clean and secure.
- As an Admin, I want to remove/delete bad products from the global list so that i stays friendly and clean
- As an Admin, I want role-based access (User, Admin, SuperAdmin) so that I only see and do what I’m allowed to.
- Given that bad actors exit, when user logs in, then they are given three attempts before being locked out for x mintus and eventually required to update their password

## Conflict handling

- As a User, I want to see a warning if I try to delete a product that is part of recipes/meals so that I don’t break dependencies accidentally.

## Data Ownership & Sharing

- As a User, I want to clone shared products/recipes/meals into my private collection so that I can keep them even if the original owner leaves.
- As a Group Member, I want to know which products/recipes/meals are owned by the group vs. an individual so that I am aware.
