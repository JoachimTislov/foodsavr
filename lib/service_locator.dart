import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

import 'constants/environment_config.dart';
import 'interfaces/auth_repository.dart';
import 'interfaces/user_repository.dart';
import 'interfaces/product_repository.dart';
import 'interfaces/collection_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/user_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/collection_repository.dart';
import 'repositories/firestore_user_repository.dart';
import 'repositories/firestore_product_repository.dart';
import 'repositories/firestore_collection_repository.dart';
import 'services/auth_service.dart';
import 'services/product_service.dart';
import 'services/seeding_service.dart';

final getIt = GetIt.instance;

/// Initialize dependency injection container.
/// Automatically switches between in-memory (dev) and Firestore (prod) based on environment.
Future<void> setupServiceLocator() async {
  // Register authentication repository
  getIt.registerLazySingleton<IAuthRepository>(
    () => FirebaseAuthRepository(FirebaseAuth.instance),
  );

  // Auto-switch based on environment
  final useFirestore = EnvironmentConfig.isProduction;

  if (useFirestore) {
    // Production: Use Firestore for persistence
    final firestore = FirebaseFirestore.instance;
    getIt.registerLazySingleton<IUserRepository>(
      () => FirestoreUserRepository(firestore),
    );
    getIt.registerLazySingleton<IProductRepository>(
      () => FirestoreProductRepository(firestore),
    );
    getIt.registerLazySingleton<ICollectionRepository>(
      () => FirestoreCollectionRepository(firestore),
    );
  } else {
    // Development: Use in-memory repositories (faster, no network)
    getIt.registerLazySingleton<IUserRepository>(
      () => InMemoryUserRepository(),
    );
    getIt.registerLazySingleton<IProductRepository>(
      () => InMemoryProductRepository(),
    );
    getIt.registerLazySingleton<ICollectionRepository>(
      () => InMemoryCollectionRepository(),
    );
  }

  // Register services
  getIt.registerLazySingleton<AuthService>(
    () => AuthService(getIt<IAuthRepository>()),
  );
  getIt.registerLazySingleton<ProductService>(
    () => ProductService(getIt<IProductRepository>()),
  );
  getIt.registerLazySingleton<SeedingService>(
    () => SeedingService(
      getIt<IUserRepository>(),
      getIt<IProductRepository>(),
      getIt<ICollectionRepository>(),
    ),
  );
}
