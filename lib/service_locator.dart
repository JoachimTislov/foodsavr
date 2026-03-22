import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

import 'injection.dart';
import 'interfaces/i_auth_service.dart';
import 'services/seeding_service.dart';
import 'utils/config.dart';

export 'injection.dart' show getIt;

class ServiceLocator {
  void registerDependencies() => configureDependencies();

  Future<void> setupDevelopment() async {
    const host = Config.emulatorHost;

    try {
      await getIt<FirebaseAuth>().useAuthEmulator(host, 9099);
      getIt<FirebaseFirestore>().useFirestoreEmulator(host, 8080);
    } catch (e) {
      getIt<Logger>().e('Error connecting to Firebase emulators: $e');
    }

    // We don't await the actual seeding/login logic here to avoid blocking runApp on web refresh.
    // The router and services will handle the transient auth state.
    _performAsyncSeeding();
  }

  Future<void> _performAsyncSeeding() async {
    final logger = getIt<Logger>();
    final authService = getIt<IAuthService>();

    // Give Firebase a moment to initialize its internal state on web
    await Future.delayed(const Duration(milliseconds: 500));

    var userId = authService.getUserId();
    try {
      // On web, sign-in might hang if the emulator host is unreachable.
      // We use a timeout to avoid blocking indefinitely.
      userId ??=
          (await authService
                  .signIn(
                    email: Config.testUserEmail,
                    password: Config.testUserPassword,
                  )
                  .timeout(const Duration(seconds: 3)))
              .user
              ?.uid;
    } catch (e) {
      logger.w('Development auto-login failed or timed out: $e');
    }

    if (userId == null) {
      logger.i('Seeding database with initial data...');
      try {
        await getIt<SeedingService>().seedDatabase();
      } catch (e) {
        logger.e('Failed to seed database: $e');
      }
    } else {
      logger.i('User already signed in, skipping seeding');
    }
  }
}
