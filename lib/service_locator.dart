import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

import 'injection.dart';
import 'interfaces/i_auth_service.dart';
import 'interfaces/i_collection_repository.dart';
import 'interfaces/i_product_repository.dart';
import 'services/seeding_service.dart';
import 'utils/config.dart';

export 'injection.dart' show getIt;

class ServiceLocator {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final Logger _logger;

  ServiceLocator(this._logger);

  Future<void> registerDependencies() async {
    if (!getIt.isRegistered<Logger>()) {
      getIt.registerLazySingleton<Logger>(() => _logger);
    }
    await configureDependencies();
  }

  Future<void> setupDevelopment() async {
    await _auth.useAuthEmulator('localhost', 9099);
    _firestore.useFirestoreEmulator('localhost', 8080);

    // Pre-check if user is already signed in to avoid redundant seeding on hot reload or full restart during development.
    final authService = getIt<IAuthService>();
    final productRepository = getIt<IProductRepository>();
    final collectionRepository = getIt<ICollectionRepository>();
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
      _logger.i('Seeding database with initial data...');
      // Only init and seed the database if no user is signed in.
      // Presumably, if the user is signed in, the emulators are already seeded and ready to go.
      // TODO: should the seed data reset on hot reload or full restart? Maybe add a flag to control this behavior?
      await SeedingService(
        authService,
        productRepository,
        collectionRepository,
        _logger,
      ).seedDatabase();
    } else {
      _logger.i('User already signed in, skipping seeding');
    }
  }
}
