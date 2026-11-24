import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/utils/app_theme.dart';
import 'package:foodsavr/views/barcode_scan_view.dart';
import 'package:foodsavr/widgets/product/expiries_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableLevels = [];
  const cameraChannel = MethodChannel('plugins.flutter.io/camera');
  for (final brightness in Brightness.values) {
    for (final screen in ['scanner', 'expiries']) {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        testWidgets('$screen accessibility in $brightness on $platform', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(const Size(800, 600));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(
            cameraChannel,
            (call) async => <Object>[],
          );
          addTearDown(
            () => messenger.setMockMethodCallHandler(cameraChannel, null),
          );
          final semantics = tester.ensureSemantics();
          await tester.pumpWidget(
            MaterialApp(
              theme: brightness == Brightness.light
                  ? AppTheme.lightTheme
                  : AppTheme.darkTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.noScaling),
                child: child!,
              ),
              home: screen == 'scanner'
                  ? const BarcodeScanView()
                  : Scaffold(
                      body: ExpiriesSection(
                        expiries: [
                          ExpiryEntry(
                            quantity: 1,
                            expirationDate: DateTime(2027),
                          ),
                        ],
                        onAdd: () {},
                        onRemove: (_) {},
                      ),
                    ),
            ),
          );
          await tester.pumpAndSettle();
          await expectLater(
            tester,
            meetsGuideline(
              platform == TargetPlatform.android
                  ? androidTapTargetGuideline
                  : iOSTapTargetGuideline,
            ),
          );
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantics.dispose();
        }, variant: TargetPlatformVariant({platform}));
      }
    }
  }
}
