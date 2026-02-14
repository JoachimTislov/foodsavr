import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:foodsavr/interfaces/auth_service.dart';
import 'package:foodsavr/services/auth_service.dart';
import 'package:foodsavr/utils/environment_config.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

import 'interfaces/collection_repository.dart';
import 'interfaces/product_repository.dart';
import 'repositories/collection_repository.dart';
import 'repositories/product_repository.dart';
import 'services/product_service.dart';
import 'services/seeding_service.dart';

final getIt = GetIt.instance;

// Initialize dependency injection container.
// Uses Firebase emulators in development, production Firebase in production.
// In development, also seeds the database with initial data for testing.
Future<void> registerDependencies(Logger logger) async {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  final authService = AuthService(auth);
  final productRepository = ProductRepository(firestore);
  final collectionRepository = CollectionRepository(firestore);

  if (EnvironmentConfig.isDevelopment) {
    await auth.useAuthEmulator('localhost', 9099);
    firestore.useFirestoreEmulator('localhost', 8080);

    logger.i('Seeding database with initial data...');
    // Seed database with initial data
    await SeedingService(
      authService,
      productRepository,
      collectionRepository,
    ).seedDatabase();
  }

  getIt.registerLazySingleton<Logger>(() => logger);
  getIt.registerLazySingleton<IProductRepository>(() => productRepository);
  getIt.registerLazySingleton<ICollectionRepository>(
    () => collectionRepository,
  );
  getIt.registerLazySingleton<IAuthService>(() => authService);
  getIt.registerLazySingleton<ProductService>(
    () => ProductService(productRepository, logger),
  );
}
