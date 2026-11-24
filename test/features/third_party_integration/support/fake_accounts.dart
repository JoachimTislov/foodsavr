import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockMetadata extends Mock implements UserMetadata {}

/// A [FirebaseAuth] whose signed-in account the test switches.
class FakeAccounts {
  FakeAccounts() {
    when(() => auth.currentUser).thenAnswer((_) => _current);
    when(() => auth.authStateChanges()).thenAnswer((_) => _changes.stream);
  }

  final FirebaseAuth auth = _MockAuth();
  final _changes = StreamController<User?>.broadcast(sync: true);
  User? _current;

  static User user(String uid, {DateTime? signedInAt}) {
    final user = _MockUser();
    final metadata = _MockMetadata();
    when(() => user.uid).thenReturn(uid);
    when(() => user.metadata).thenReturn(metadata);
    when(
      () => metadata.lastSignInTime,
    ).thenReturn(signedInAt ?? DateTime.utc(2026, 1, 1));
    return user;
  }

  /// Switches the account (null signs out); listeners run synchronously.
  Future<void> use(User? user) async {
    _current = user;
    _changes.add(user);
  }
}
