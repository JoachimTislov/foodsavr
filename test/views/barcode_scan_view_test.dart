import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/views/barcode_scan_view.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _Preferences extends Mock implements PreferencesController {}

class _AuthService extends Mock implements IAuthService {}

class _ProductService extends Mock implements ProductService {}

class _CollectionService extends Mock implements CollectionService {}

void main() {
  const cameraChannel = MethodChannel('plugins.flutter.io/camera');
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableLevels = [];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(cameraChannel, null);
  });

  for (final scenario in [
    if (kIsWeb)
      'web'
    else ...[
      'unsupported platform',
      'no camera',
      'denied permission',
    ],
  ]) {
    final platform = scenario == 'unsupported platform'
        ? TargetPlatform.linux
        : TargetPlatform.android;
    testWidgets('manual barcode works with $scenario', (tester) async {
      final cameraCalls = <String>[];
      messenger.setMockMethodCallHandler(cameraChannel, (call) async {
        cameraCalls.add(call.method);
        if (call.method == 'dispose') return null;
        if (scenario == 'denied permission') {
          if (call.method == 'availableCameras') {
            return [
              {'name': 'back', 'lensFacing': 'back', 'sensorOrientation': 90},
            ];
          }
          throw PlatformException(code: 'CameraAccessDenied');
        }
        return <Object>[];
      });

      Object? result;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await context.push<Object>('/barcode-scan');
                },
                child: const Text('Open barcode flow'),
              ),
            ),
          ),
          GoRoute(
            path: '/barcode-scan',
            builder: (context, state) => const BarcodeScanView(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Open barcode flow'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.flash_off), findsNothing);
      final submit = find.widgetWithText(FilledButton, 'product.useBarcode');
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.enterText(find.byType(TextField), ' 0012345678905 ');
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(result, '0012345678905');
      expect(cameraCalls, switch (scenario) {
        'unsupported platform' || 'web' => isEmpty,
        'denied permission' => ['availableCameras', 'create', 'dispose'],
        _ => ['availableCameras'],
      });
    }, variant: TargetPlatformVariant.only(platform));
  }

  testWidgets('a direct scanner route can submit without a caller', (
    tester,
  ) async {
    final preferences = _Preferences();
    when(preferences.resolveDefaultInventoryId).thenAnswer((_) async => null);
    getIt.registerSingleton<PreferencesController>(preferences);
    getIt.registerSingleton<IAuthService>(_AuthService());
    getIt.registerSingleton<ProductService>(_ProductService());
    getIt.registerSingleton<CollectionService>(_CollectionService());
    addTearDown(getIt.reset);

    final router = GoRouter(
      initialLocation: '/barcode-scan',
      routes: [
        GoRoute(
          path: '/barcode-scan',
          builder: (context, state) => const BarcodeScanView(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(find.byType(TextField), '0012345678905');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'product.useBarcode'));
    await tester.pumpAndSettle();

    verify(preferences.resolveDefaultInventoryId).called(1);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
