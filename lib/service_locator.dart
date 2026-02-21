import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

import 'interfaces/i_auth_service.dart';
import 'repositories/collection_repository.dart';
import 'repositories/product_repository.dart';
import 'services/auth_controller.dart';
import 'services/auth_service.dart';
import 'services/collection_service.dart';
import 'services/product_service.dart';
import 'services/seeding_service.dart';
import 'utils/config.dart';

final getIt = GetIt.instance;

class ServiceLocator {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  late final Logger _logger;
  late final AuthService _authService;
  late final ProductRepository _productRepository;
  late final CollectionRepository _collectionRepository;

  ServiceLocator(Logger logger) {
    _logger = logger;
    _authService = AuthService(_auth);
    _productRepository = ProductRepository(_firestore);
    _collectionRepository = CollectionRepository(_firestore);
  }

  Future<void> registerDependencies() async {
    getIt.registerLazySingleton<Logger>(() => _logger);
    getIt.registerLazySingleton<IAuthService>(() => _authService);
    getIt.registerFactory<AuthController>(
      () => AuthController(getIt<IAuthService>(), getIt<Logger>()),
    );
    getIt.registerLazySingleton<ProductService>(
      () => ProductService(_productRepository, _logger),
    );
    getIt.registerLazySingleton<CollectionService>(
      () => CollectionService(_collectionRepository, _logger),
    );
  }

  Future<void> setupDevelopment() async {
    await _auth.useAuthEmulator('localhost', 9099);
    _firestore.useFirestoreEmulator('localhost', 8080);

    // Pre-check if user is already signed in to avoid redundant seeding on hot reload or full restart during development.
    var userId = _authService.getUserId();
    try {
      userId ??= (await _authService.signIn(
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
        _authService,
        _productRepository,
        _collectionRepository,
        _logger,
      ).seedDatabase();
    } else {
      _logger.i('User already signed in, skipping seeding');
    }
  }
}
