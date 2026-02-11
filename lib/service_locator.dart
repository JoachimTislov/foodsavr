import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

import 'utils/environment_config.dart';
import 'interfaces/auth_repository.dart';
import 'interfaces/user_repository.dart';
import 'interfaces/product_repository.dart';
import 'interfaces/collection_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/firestore_user_repository.dart';
import 'repositories/firestore_product_repository.dart';
import 'repositories/firestore_collection_repository.dart';
import 'services/auth_service.dart';
import 'services/product_service.dart';
import 'services/seeding_service.dart';

final getIt = GetIt.instance;

/// Initialize dependency injection container.
/// Uses Firebase emulators in development, production Firebase in production.
Future<void> setupServiceLocator() async {
  final firebaseAuth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  // Connect to emulators in development
  if (EnvironmentConfig.isDevelopment) {
    await firebaseAuth.useAuthEmulator('localhost', 9099);
    firestore.useFirestoreEmulator('localhost', 8080);
  }

  // Register repositories
  getIt.registerLazySingleton<IAuthRepository>(
    () => FirebaseAuthRepository(firebaseAuth),
  );
  getIt.registerLazySingleton<IUserRepository>(
    () => FirestoreUserRepository(firestore),
  );
  getIt.registerLazySingleton<IProductRepository>(
    () => FirestoreProductRepository(firestore),
  );
  getIt.registerLazySingleton<ICollectionRepository>(
    () => FirestoreCollectionRepository(firestore),
  );

  // Register services
  getIt.registerLazySingleton<AuthService>(
    () => AuthService(getIt<IAuthRepository>()),
  );
  getIt.registerLazySingleton<ProductService>(
    () => ProductService(getIt<IProductRepository>()),
  );
  getIt.registerLazySingleton<SeedingService>(
    () => SeedingService(
      getIt<IAuthRepository>(),
      getIt<IProductRepository>(),
      getIt<ICollectionRepository>(),
    ),
  );
}
