import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_translation_loader.dart';

class MockAuthService extends Mock implements IAuthService {}

class MockUser extends Mock implements User {}

class MockUserInfo extends Mock implements UserInfo {}

UserInfo providerInfo(String providerId, {String? email}) {
  final info = MockUserInfo();
  when(() => info.providerId).thenReturn(providerId);
  when(() => info.email).thenReturn(email);
  return info;
}

MockUser signedInUser(
  List<UserInfo> providers, {
  String? email = 'kari@example.com',
  bool isAnonymous = false,
}) {
  final user = MockUser();
  when(() => user.isAnonymous).thenReturn(isAnonymous);
  when(() => user.email).thenReturn(email);
  when(() => user.providerData).thenReturn(providers);
  return user;
}

TestTranslationLoader? _translations;

/// Call from `setUp`.
Future<void> setUpSettingsWidgetTest() async {
  EasyLocalization.logger.enableBuildModes = [];
  EasyLocalization.logger.enableLevels = [];
  await getIt.reset();
  getIt.registerSingleton<Logger>(Logger(level: Level.off));
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  _translations = TestTranslationLoader();
}

/// Pumps [child] in a window [width] logical pixels wide.
Future<void> pumpSettingsWidget(
  WidgetTester tester,
  Widget child, {
  double width = 800,
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en')],
      startLocale: const Locale('en'),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: _translations!,
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
