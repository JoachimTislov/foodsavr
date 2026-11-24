import 'package:integration_test/integration_test.dart';

import 'auth_test.dart';
import 'firestore_crud_test.dart';

/// Consolidated integration test entrypoint so Android CI compiles, installs,
/// and boots the instrumentation APK once for all suites.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerAuthTests();
  registerFirestoreCrudTests();
}
