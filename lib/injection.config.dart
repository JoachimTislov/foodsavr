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
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:foodsavr/controllers/c_auth.dart' as _i545;
import 'package:foodsavr/features/third_party_integration/interfaces/i_import_service.dart'
    as _i266;
import 'package:foodsavr/features/third_party_integration/interfaces/i_oauth_service.dart'
    as _i941;
import 'package:foodsavr/features/third_party_integration/oauth_controller.dart'
    as _i993;
import 'package:foodsavr/features/third_party_integration/services/import_service.dart'
    as _i889;
import 'package:foodsavr/features/third_party_integration/services/oauth_service.dart'
    as _i649;
import 'package:foodsavr/interfaces/ir_collection.dart' as _i1020;
import 'package:foodsavr/interfaces/ir_product.dart' as _i766;
import 'package:foodsavr/interfaces/is_auth.dart' as _i451;
import 'package:foodsavr/register_module.dart' as _i327;
import 'package:foodsavr/repositories/r_collection.dart' as _i649;
import 'package:foodsavr/repositories/r_product.dart' as _i670;
import 'package:foodsavr/services/s_barcode_scanner.dart' as _i1065;
import 'package:foodsavr/services/s_collection.dart' as _i526;
import 'package:foodsavr/services/s_firebase_auth.dart' as _i640;
import 'package:foodsavr/services/s_product.dart' as _i201;
import 'package:foodsavr/services/s_secure_storage.dart' as _i169;
import 'package:foodsavr/services/s_seeding.dart' as _i322;
import 'package:foodsavr/utils/u_shelf_life.dart' as _i601;
import 'package:foodsavr/utils/u_theme_notifier.dart' as _i998;
import 'package:get_it/get_it.dart' as _i174;
import 'package:google_sign_in/google_sign_in.dart' as _i116;
import 'package:http/http.dart' as _i519;
import 'package:injectable/injectable.dart' as _i526;
import 'package:logger/logger.dart' as _i974;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    gh.factory<_i1065.BarcodeScannerService>(
      () => _i1065.BarcodeScannerService(),
    );
    gh.singleton<_i974.Logger>(() => registerModule.logger);
    await gh.singletonAsync<_i460.SharedPreferencesWithCache>(
      () => registerModule.prefs,
      preResolve: true,
    );
    gh.singleton<_i998.ThemeNotifier>(() => registerModule.themeNotifier);
    gh.lazySingleton<_i806.FacebookAuth>(() => registerModule.facebookAuth);
    gh.lazySingleton<_i59.FirebaseAuth>(() => registerModule.firebaseAuth);
    gh.lazySingleton<_i974.FirebaseFirestore>(
      () => registerModule.firebaseFirestore,
    );
    gh.lazySingleton<_i116.GoogleSignIn>(() => registerModule.googleSignIn);
    gh.lazySingleton<_i558.FlutterSecureStorage>(
      () => registerModule.flutterSecureStorage,
    );
    gh.lazySingleton<_i519.Client>(() => registerModule.httpClient);
    gh.lazySingleton<_i322.SeedingService>(() => _i322.SeedingService.create());
    gh.lazySingleton<_i601.ShelfLifeService>(() => _i601.ShelfLifeService());
    gh.singleton<_i169.SecureStorage>(
      () => _i169.SecureStorage(gh<_i558.FlutterSecureStorage>()),
    );
    gh.factory<bool>(
      () => registerModule.supportsPersistence,
      instanceName: 'supportsPersistence',
    );
    gh.lazySingleton<_i451.IAuthService>(
      () => _i640.AuthService(
        gh<_i59.FirebaseAuth>(),
        googleSignIn: gh<_i116.GoogleSignIn>(),
        facebookAuth: gh<_i806.FacebookAuth>(),
        supportsPersistence: gh<bool>(instanceName: 'supportsPersistence'),
        firestore: gh<_i974.FirebaseFirestore>(),
      ),
    );
    gh.lazySingleton<_i941.IOAuthService>(
      () => _i649.OAuthService(gh<_i974.Logger>(), gh<_i169.SecureStorage>()),
    );
    gh.lazySingleton<_i766.IProductRepository>(
      () => _i670.ProductRepository(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i266.IImportService>(
      () => _i889.ImportService(
        gh<_i974.Logger>(),
        gh<_i169.SecureStorage>(),
        gh<_i519.Client>(),
      ),
    );
    gh.factoryParam<_i545.AuthController, _i545.Translator?, dynamic>(
      (translate, _) => _i545.AuthController(
        gh<_i451.IAuthService>(),
        gh<_i974.Logger>(),
        translate: translate,
      ),
    );
    gh.lazySingleton<_i1020.ICollectionRepository>(
      () => _i649.CollectionRepository(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i526.CollectionService>(
      () => _i526.CollectionService(
        gh<_i1020.ICollectionRepository>(),
        gh<_i974.Logger>(),
      ),
    );
    gh.lazySingleton<_i201.ProductService>(
      () => _i201.ProductService(
        gh<_i766.IProductRepository>(),
        gh<_i601.ShelfLifeService>(),
        gh<_i974.Logger>(),
      ),
    );
    gh.factory<_i993.OAuthController>(
      () =>
          _i993.OAuthController(gh<_i941.IOAuthService>(), gh<_i974.Logger>()),
    );
    return this;
  }
}

class _$RegisterModule extends _i327.RegisterModule {}
