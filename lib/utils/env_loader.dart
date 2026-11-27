import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Asset path of the bundled environment file.
const envAssetPath = 'assets/.env';

/// Base64 environment compiled into the app by `scripts/web/deploy_web.py`.
const _compiledEnvB64 = String.fromEnvironment('BUNDLED_ENV_B64');

/// Loads the app environment into [dotenv].
///
/// A non-empty [bundledEnvB64] (hosted web builds) is the only source; local
/// and mobile builds leave it empty and read the [envAssetPath] asset. Both are
/// optional: a missing, empty or undecodable environment yields an empty one
/// instead of failing startup. Integrations read their keys at use time.
Future<void> loadEnv({AssetBundle? bundle, String? bundledEnvB64}) async {
  final encoded = bundledEnvB64 ?? _compiledEnvB64;
  final contents = encoded.isEmpty
      ? await _readEnvAsset(bundle ?? rootBundle)
      : _decodeEnv(encoded);
  dotenv.loadFromString(envString: contents, isOptional: true);
}

String _decodeEnv(String encoded) {
  try {
    return utf8.decode(base64.decode(encoded.replaceAll(RegExp(r'\s'), '')));
  } on FormatException {
    // The exception quotes its input, so it is not logged.
    debugPrint('BUNDLED_ENV_B64 is not Base64-encoded UTF-8; ignoring it.');
    return '';
  }
}

Future<String> _readEnvAsset(AssetBundle bundle) async {
  try {
    return await bundle.loadString(envAssetPath);
  } on FlutterError {
    // Asset not bundled: treat as empty.
    return '';
  }
}
