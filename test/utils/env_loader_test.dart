import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/features/third_party_integration/services/import_service.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/services/secure_storage_service.dart';
import 'package:foodsavr/utils/env_loader.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthService extends Mock implements IAuthService {}

/// Bundle serving [content] for [envAssetPath], or no asset when null.
class _EnvBundle extends CachingAssetBundle {
  _EnvBundle(this.content);

  final String? content;

  @override
  Future<ByteData> load(String key) async {
    if (key != envAssetPath || content == null) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content!)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('loadEnv', () {
    test('succeeds when the bundled env file is empty', () async {
      await loadEnv(bundle: _EnvBundle(''));

      expect(dotenv.isInitialized, isTrue);
      expect(dotenv.maybeGet('REMA_API_URL'), isNull);
    });

    test('succeeds when the bundled env file is missing', () async {
      await loadEnv(bundle: _EnvBundle(null));

      expect(dotenv.isInitialized, isTrue);
    });

    test('loads values when the env file is populated', () async {
      await loadEnv(bundle: _EnvBundle('REMA_API_URL=https://rema.example\n'));

      expect(dotenv.get('REMA_API_URL'), 'https://rema.example');
    });
  });

  group('startup with an empty env file', () {
    setUp(() async {
      await loadEnv(bundle: _EnvBundle(''));
    });

    test('ImportService construction reads no env values', () {
      expect(
        () => ImportService(
          _MockAuthService(),
          Logger(),
          SecureStorage(const FlutterSecureStorage()),
          http.Client(),
        ),
        returnsNormally,
      );
    });

    test('provider support checks do not throw', () {
      expect(Provider.rema.isSupported, returnsNormally);
    });
  });
}
