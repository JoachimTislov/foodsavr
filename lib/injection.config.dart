// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:cloud_firestore/cloud_firestore.dart' as _i974;
import 'package:firebase_auth/firebase_auth.dart' as _i59;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart' as _i806;
import 'package:foodsavr/di/register_module.dart' as _i966;
import 'package:foodsavr/interfaces/i_auth_service.dart' as _i794;
import 'package:foodsavr/interfaces/i_collection_repository.dart' as _i655;
import 'package:foodsavr/interfaces/i_product_repository.dart' as _i424;
import 'package:foodsavr/repositories/collection_repository.dart' as _i92;
import 'package:foodsavr/repositories/product_repository.dart' as _i318;
import 'package:foodsavr/services/auth_controller.dart' as _i882;
import 'package:foodsavr/services/auth_service.dart' as _i277;
import 'package:foodsavr/services/collection_service.dart' as _i122;
import 'package:foodsavr/services/product_service.dart' as _i898;
import 'package:foodsavr/services/seeding_service.dart' as _i464;
import 'package:get_it/get_it.dart' as _i174;
import 'package:google_sign_in/google_sign_in.dart' as _i116;
import 'package:injectable/injectable.dart' as _i526;
import 'package:logger/logger.dart' as _i974;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    gh.lazySingleton<_i59.FirebaseAuth>(() => registerModule.firebaseAuth);
    gh.lazySingleton<_i974.FirebaseFirestore>(
      () => registerModule.firebaseFirestore,
    );
    gh.lazySingleton<_i116.GoogleSignIn>(() => registerModule.googleSignIn);
    gh.lazySingleton<_i806.FacebookAuth>(() => registerModule.facebookAuth);
    gh.lazySingleton<_i794.IAuthService>(
      () => _i277.AuthService(
        gh<_i59.FirebaseAuth>(),
        googleSignIn: gh<_i116.GoogleSignIn>(),
        facebookAuth: gh<_i806.FacebookAuth>(),
        supportsPersistence: gh<bool>(),
      ),
    );
    gh.lazySingleton<_i424.IProductRepository>(
      () => _i318.ProductRepository(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i655.ICollectionRepository>(
      () => _i92.CollectionRepository(gh<_i974.FirebaseFirestore>()),
    );
    gh.factory<_i882.AuthController>(
      () => registerModule.authController(
        gh<_i794.IAuthService>(),
        gh<_i974.Logger>(),
      ),
    );
    gh.factory<_i464.SeedingService>(
      () => _i464.SeedingService(
        gh<_i794.IAuthService>(),
        gh<_i424.IProductRepository>(),
        gh<_i655.ICollectionRepository>(),
        gh<_i974.Logger>(),
      ),
    );
    gh.lazySingleton<_i122.CollectionService>(
      () => _i122.CollectionService(
        gh<_i655.ICollectionRepository>(),
        gh<_i974.Logger>(),
      ),
    );
    gh.lazySingleton<_i898.ProductService>(
      () => _i898.ProductService(
        gh<_i424.IProductRepository>(),
        gh<_i974.Logger>(),
      ),
    );
    return this;
  }
}

class _$RegisterModule extends _i966.RegisterModule {}
