// Production Firebase project options, selected by
// `--dart-define=DEPLOY_ENVIRONMENT=production` (lib/main.dart).
//
// Placeholder until `make setup` provisions the production project. Hosting
// deploys regenerate this file from that project at build time
// (scripts/web/write_web_config.py), so only a build outside that path can
// reach the placeholder, and it then fails at startup instead of silently
// using the test project.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class ProdFirebaseOptions {
  /// Whether this file holds a real production project's options.
  static const bool configured = false;

  static FirebaseOptions get currentPlatform => throw StateError(
    'Production Firebase options are not configured. Provision the '
    'production project with `make setup`, then deploy with '
    '`make deploy-web ENV=production`.',
  );
}
