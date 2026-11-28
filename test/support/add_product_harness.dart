import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/barcode_scanner_service.dart';
import 'package:foodsavr/services/camera_permission_service.dart';
import 'package:foodsavr/services/camera_preference_service.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/expiry_scanner_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/shelf_life.dart';
import 'package:foodsavr/validation/validators/product_model_validator.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fake_camera_access.dart';
import 'fake_open_food_facts.dart';
import 'fake_product_repository.dart';

class _Auth extends Mock implements IAuthService {}

class _Collections extends Mock implements CollectionService {}

class _Preferences extends Mock implements PreferencesController {}

class _ExpiryScanner extends Mock implements ExpiryScannerService {}

/// The services behind the add-product flows, over in-memory fakes.
class AddProductHarness {
  final repository = FakeProductRepository();
  final openFoodFacts = FakeOpenFoodFacts();
  final camera = FakeCameraAccess();
  final preference = CameraPreferenceService();

  /// Calls the camera plugin received.
  final List<String> cameraCalls = [];

  Future<void> register() async {
    await getIt.reset();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    BarcodeScannerService.refreshCameraDetection();

    final auth = _Auth();
    when(auth.getUserId).thenReturn('user');
    final collections = _Collections();
    when(() => collections.getCollection('inv')).thenAnswer(
      (_) async => const Collection(
        id: 'inv',
        name: 'Fridge',
        productIds: [],
        userId: 'user',
      ),
    );
    when(
      () => collections.addProductToCollection(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => collections.getCollectionsForUser('user', type: any(named: 'type')),
    ).thenAnswer((_) async => []);
    final preferences = _Preferences();
    when(preferences.resolveDefaultInventoryId).thenAnswer((_) async => null);
    when(
      () => preferences.resolveDefaultInventoryId(userId: 'user'),
    ).thenAnswer((_) async => null);
    when(() => preferences.expiringSoonDays).thenReturn(6);
    final scanner = _ExpiryScanner();
    when(scanner.close).thenAnswer((_) async {});

    getIt
      ..registerSingleton<Logger>(Logger(level: Level.off))
      ..registerSingleton<IAuthService>(auth)
      ..registerSingleton<CollectionService>(collections)
      ..registerSingleton<PreferencesController>(preferences)
      ..registerSingleton<CameraPreferenceService>(preference)
      ..registerSingleton<CameraPermissionService>(
        CameraPermissionService.withPlatform(preference, camera),
      )
      ..registerSingleton<ExpiryScannerService>(scanner)
      ..registerSingleton<ProductService>(
        ProductService(
          repository,
          ProductModelValidator(),
          ShelfLifeService(),
          Logger(level: Level.off),
          offClient: openFoodFacts.client,
        ),
      );
  }

  /// Gives the device a back camera that refuses to start, as when the user
  /// denies access, or no camera at all.
  void mockDeviceCamera(WidgetTester tester, {bool present = true}) {
    const channel = MethodChannel('plugins.flutter.io/camera');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      cameraCalls.add(call.method);
      if (call.method == 'dispose') return null;
      if (call.method == 'availableCameras') {
        return [
          if (present)
            {'name': 'back', 'lensFacing': 'back', 'sensorOrientation': 90},
        ];
      }
      throw PlatformException(code: 'CameraAccessDenied');
    });
    BarcodeScannerService.refreshCameraDetection();
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  /// A window tall enough for the whole Add Product form.
  void useTallWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The test font is far wider than the real one.
    tester.platformDispatcher.textScaleFactorTestValue = 0.5;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
  }
}
