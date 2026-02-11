import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foodsavr/interfaces/auth_service.dart';
import 'package:foodsavr/services/auth_service.dart';
import 'package:get_it/get_it.dart';

import 'interfaces/product_repository.dart';
import 'interfaces/collection_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/collection_repository.dart';
import 'services/product_service.dart';
import 'services/seeding_service.dart';

final getIt = GetIt.instance;

/// Initialize dependency injection container.
/// Uses Firebase emulators in development, production Firebase in production.
Future<void> registerDependencies(
  FirebaseAuth auth,
  FirebaseFirestore firestore,
) async {
  getIt.registerLazySingleton<IProductRepository>(
    () => ProductRepository(firestore),
  );
  getIt.registerLazySingleton<ICollectionRepository>(
    () => CollectionRepository(firestore),
  );

  // Register services
  getIt.registerLazySingleton<IAuthService>(() => AuthService(auth));
  getIt.registerLazySingleton<ProductService>(
    () => ProductService(getIt<IProductRepository>()),
  );
  getIt.registerLazySingleton<SeedingService>(
    () => SeedingService(
      getIt<IAuthService>(),
      getIt<IProductRepository>(),
      getIt<ICollectionRepository>(),
    ),
  );
}
