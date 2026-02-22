import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

import 'injection.dart';
import 'interfaces/i_auth_service.dart';
import 'services/seeding_service.dart';
import 'utils/config.dart';

export 'injection.dart' show getIt;

class ServiceLocator {
  Future<void> registerDependencies() async => await configureDependencies();

  Future<void> setupDevelopment() async {
    await getIt<FirebaseAuth>().useAuthEmulator('localhost', 9099);
    getIt<FirebaseFirestore>().useFirestoreEmulator('localhost', 8080);

    // Pre-check if user is already signed in to avoid redundant seeding on hot reload or full restart during development.
    final logger = getIt<Logger>();
    final authService = getIt<IAuthService>();
    var userId = authService.getUserId();
    try {
      userId ??= (await authService.signIn(
        email: Config.testUserEmail,
        password: Config.testUserPassword,
      )).user?.uid;
    } catch (_) {
      // ignore error ...
    }
    if (userId == null) {
      logger.i('Seeding database with initial data...');
      // Only init and seed the database if no user is signed in.
      // Presumably, if the user is signed in, the emulators are already seeded and ready to go.
      // TODO: should the seed data reset on hot reload or full restart? Maybe add a flag to control this behavior?
      await getIt<SeedingService>().seedDatabase();
    } else {
      logger.i('User already signed in, skipping seeding');
    }
  }
}
