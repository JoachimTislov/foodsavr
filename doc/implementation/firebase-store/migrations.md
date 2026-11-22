# Firestore schema evolution and migrations

Firestore is schemaless on write and schema-dependent on read. Because mobile
clients upgrade asynchronously, you must design document changes so older app
versions do not crash on new fields and newer app versions handle older
documents safely.

## Core principles

Follow these practices for every Firestore model change:

1. **Prefer additive changes:** Add new fields instead of renaming or removing
   existing ones in place. Older clients ignore unknown fields.
2. **Provide model defaults:** Give Dart model deserializers safe defaults for
   missing fields so newer clients can read older documents without null errors.
3. **Version documents explicitly:** Include an integer `schemaVersion` field
   on documents that evolve structurally so parsers know which shape they are
   reading.
4. **Avoid force-unwrapping:** Handle `null` values defensively unless security
   rules and completed migrations guarantee the field exists.

## Migration strategies

Choose the lightest strategy that satisfies the scope and risk of the change.

### Lazy (client-side) migration

Transform documents on read when `schemaVersion` is older than the current app
version, and optionally write the upgraded shape back on save.

- **Best for:** Mobile apps with asynchronous upgrades and incremental field
  changes.
- **Trade-offs:** Zero downtime and low write volume because only active
  documents migrate, at the cost of keeping reader compatibility logic until
  old versions retire.

### In-place batch (server-side) migration

Run an administrative script against Firestore to update all documents matching
an older schema in batches (up to 500 writes per batch).

- **Best for:** Cleanup after a rollout or structural changes that must apply
  uniformly across inactive accounts.
- **Trade-offs:** Higher read/write cost and coordination with client releases.

FoodSavr includes a declarative batch migration runner at
`scripts/update_schema.dart`. It reads protected field guards from
`migrations/permanent.json`, applies JSON migration definitions from
`migrations/`, and records applied migrations in the `_migrations` collection.

### Expand and contract (parallel change)

Use a three-step rollout for breaking field renames or structural moves:

1. **Expand:** Add the new field. Update clients to write both the old and new
   fields while continuing to read the old field.
2. **Migrate:** Backfill existing documents so every record populates the new
   field.
3. **Contract:** Switch clients to read and write only the new field. Once old
   client versions are retired, remove the legacy field.

### Versioned collections

For major model overhauls where in-place compatibility is impractical, write to
a new collection (for example, `users_v2`) and migrate traffic cleanly.

## Flutter implementation with `withConverter`

Centralize lazy migration logic inside Firestore converters and model
deserializers so UI and service layers stay unaware of legacy document shapes.

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

    if (version == 1) {
      final name = json['name'] as String? ?? '';
      final parts = name.split(' ');
      return UserModel(
        id: id,
        firstName: parts.isNotEmpty ? parts.first : '',
        lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
        schemaVersion: 2,
      );
    }

    return UserModel(
      id: id,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      schemaVersion: version,
    );
  }

  Map<String, Object?> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'schemaVersion': 2,
  };
}
```

Attach the converter at the collection boundary:

```dart
final usersCollection = FirebaseFirestore.instance
    .collection('users')
    .withConverter<UserModel>(
      fromFirestore: (snapshot, _) =>
          UserModel.fromJson(snapshot.id, snapshot.data()!),
      toFirestore: (user, _) => user.toJson(),
    );
```

When you want to persist lazily upgraded documents back to Firestore, check the
version in the repository layer after reading and write back with
`SetOptions(merge: true)`.

## Related files

- `scripts/update_schema.dart`: Declarative batch schema migration runner.
- `migrations/permanent.json`: Protected fields that batch migrations must not
  drop (`id`, `userId`, `createdAt`, `updatedAt`, `email`, `schemaVersion`).
- [Firestore rules](rules.md): Security rules that enforce document contracts.
