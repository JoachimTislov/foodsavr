import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Asset path of the bundled environment file.
const envAssetPath = 'assets/.env';

/// Loads the bundled environment file into [dotenv].
///
/// The file is optional: a missing or empty file yields an empty environment
/// instead of failing startup. Integrations read their keys at use time.
Future<void> loadEnv({AssetBundle? bundle}) async {
  var contents = '';
  try {
    contents = await (bundle ?? rootBundle).loadString(envAssetPath);
  } on FlutterError {
    // Asset not bundled: treat as empty.
  }
  dotenv.loadFromString(envString: contents, isOptional: true);
}
