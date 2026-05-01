# Practical Implementation in Flutter/Dart

When using Flutter with Firestore, the `withConverter` method provided by `cloud_firestore` is the perfect place to implement **Lazy Migrations** and handle schema evolution centrally.

### Using `withConverter` for Migrations

By centralizing the serialization/deserialization logic, your UI and business logic layers never have to worry about legacy data formats.

```dart
class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final int schemaVersion;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.schemaVersion,
  });

  factory UserModel.fromJson(String id, Map<String, Object?> json) {
    final version = json['schemaVersion'] as int? ?? 1;

    // Lazy Migration Logic
    if (version == 1) {
      // v1 had a single 'name' field. We must split it.
      final name = json['name'] as String? ?? '';
      final parts = name.split(' ');
      
      return UserModel(
        id: id,
        firstName: parts.isNotEmpty ? parts.first : '',
        lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
        schemaVersion: 2, // Upgrade to current version in memory
      );
    }

    // v2+ parsing
    return UserModel(
      id: id,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      schemaVersion: version,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'schemaVersion': 2, // Always write the latest version
    };
  }
}
```

### Implementing the Converter

```dart
final usersCollection = FirebaseFirestore.instance
    .collection('users')
    .withConverter<UserModel>(
      fromFirestore: (snapshot, _) => UserModel.fromJson(snapshot.id, snapshot.data()!),
      toFirestore: (user, _) => user.toJson(),
    );
```

### Writing Back Migrated Data (Optional JIT Save)
If you want to persist the lazily migrated data back to Firestore to save future processing, you can do this within your Repository layer right after fetching:

```dart
Future<UserModel> getUser(String id) async {
  final doc = await usersCollection.doc(id).get();
  final user = doc.data();
  
  if (user != null && user.schemaVersion < CURRENT_SCHEMA_VERSION) {
      // Data was migrated in-memory by fromJson.
      // Now save the updated version back to the database.
      await usersCollection.doc(id).set(user, SetOptions(merge: true));
  }
  
  return user;
}
```